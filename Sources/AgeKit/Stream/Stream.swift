import Foundation
import CryptoKit

let chunkSize = 64 * 1024
let tagSize = 16 // Go: poly1305.TagSize
let encChunkSize = chunkSize + tagSize
let lastChunkFlag: UInt8 = 0x01

public struct Nonce {
    static let size = 12
    private(set) var nonce = Data(repeating: 0, count: size)

    public mutating func increment() {
        for i in (0...nonce.count-2).reversed() {
            nonce[i] += 1
            if nonce[i] != 0 {
                break
            }
            assert(i != 0, "stream: chunk counter wrapped around")
        }
    }

    public mutating func setLastChunkFlag() {
        nonce[nonce.count-1] = lastChunkFlag
    }

    public func isLast() -> Bool {
        return self.nonce.last! == lastChunkFlag
    }

    public func isZero() -> Bool {
        return self.nonce.allSatisfy { $0 == 0 }
    }
}

enum StreamError: Error {
    case unexpectedEOF
    case lastChunkEmpty
    case trailingData
    case unexpectedEmptyChunk
    case decryptFailure
}

public struct StreamReader {
    private var aead: SymmetricKey
    private var src: InputStream

    private var encryptedChunk = Data(capacity: encChunkSize)
    private var chunk: Data?
    private var nonce = Nonce()

    init(fileKey: SymmetricKey, src: InputStream) {
        self.aead = fileKey
        self.src = src
    }

    public mutating func read(_ buf: inout Data) throws -> Int {
        if let chunk = self.chunk, chunk.count > 0 {
            // Even though prefix returns Data, re-wrap it to make sure the start index is 0
            buf = Data(chunk.prefix(buf.count))
            self.chunk = chunk.dropFirst(buf.count)
            return buf.count
        }
        if buf.count == 0 {
            return 0
        }

        try readChunk()
        guard let chunk = self.chunk else {
            throw StreamError.unexpectedEmptyChunk
        }
        buf = Data(chunk.prefix(buf.count))
        self.chunk = chunk[buf.count...]
        if self.nonce.isLast() {
            var b = [UInt8]()
            b.reserveCapacity(1)
            if self.src.read(&b, maxLength: 1) > 0 {
                throw StreamError.trailingData
            }
        }
        return buf.count
    }

    private mutating func readChunk() throws {
        var buf = [UInt8](repeating: 0, count: encChunkSize)
        let n = self.src.read(&buf, maxLength: encChunkSize)
        if n == 0 {
            throw StreamError.unexpectedEOF
        }
        self.encryptedChunk = Data(buf[..<n])
        // The last chunk can be short, but not empty unless it's the first and only chunk.
        if n < encChunkSize {
            if !self.nonce.isZero() && n == ChaChaPoly.overhead {
                throw StreamError.lastChunkEmpty
            }
            self.nonce.setLastChunkFlag()
        }

        let sealedBox = try ChaChaPoly.SealedBox(combined: self.nonce.nonce+self.encryptedChunk)
        self.chunk = try? ChaChaPoly.open(sealedBox, using: self.aead)
        if self.chunk == nil && !self.nonce.isLast() {
            self.nonce.setLastChunkFlag()
            let sealedBox = try ChaChaPoly.SealedBox(combined: self.nonce.nonce+self.encryptedChunk)
            self.chunk = try ChaChaPoly.open(sealedBox, using: self.aead)
        }
        if self.chunk == nil {
            throw StreamError.decryptFailure
        }
        self.nonce.increment()
    }
}

public struct StreamWriter {
    private let aead: SymmetricKey
    private var dst: OutputStream

    private var chunk = Data(capacity: chunkSize)
    private var nonce = Nonce()

    init(fileKey: SymmetricKey, dst: OutputStream) {
        self.aead = fileKey
        self.dst = dst
    }

    public mutating func write(_ buf: inout Data) throws -> Int {
        guard buf.count > 0 else {
            return 0
        }

        var bytesWritten = 0
        while !buf.isEmpty {
            let toWrite = min(chunkSize - self.chunk.count, buf.count)
            self.chunk.append(buf[..<toWrite])
            bytesWritten += toWrite
            // Need to re-wrap the subscript of buf as Data() here.
            // Subscripting doesn't reset the indices.
            buf = Data(buf[toWrite...])

            assert(buf.isEmpty || self.chunk.count == chunkSize)

            if !buf.isEmpty {
                try self.flushChunk(last: false)
                self.chunk.removeAll(keepingCapacity: true)
            }
        }
        return bytesWritten
    }

    public mutating func write(_ str: String) throws -> Int {
        var d = str.data(using: .utf8)!
        return try write(&d)
    }

    /// Flushes the last chunk. It does not close the underlying `OutputStream`.
    public mutating func close() throws {
        try self.flushChunk(last: true)
    }

    private mutating func flushChunk(last: Bool) throws {
        if !last {
            assert(self.chunk.count == chunkSize, "stream: internal error: flush called with partial chunk")
        }

        if last {
            self.nonce.setLastChunkFlag()
        }

        let nonce = try ChaChaPoly.Nonce(data: self.nonce.nonce)
        let enc = try ChaChaPoly.seal(self.chunk, using: self.aead, nonce: nonce)
        // Note that in other languages seal returns the ciphertext and tag.
        // CryptoKit's SealedBox usually works on the .combined property which also contains the nonce.
        // To be cross-platform compatible we need to exclude the nonce.
        _ = try self.dst.write(enc.combined.dropFirst(Nonce.size))
        self.nonce.increment()
    }
}

