import Foundation
import NIOCore

extension ByteBuffer {
    /// Create a fresh ByteBuffer from the given `InputStream`.
    ///
    /// The entire `InputStream` is consumed into the buffer.
    init(_ input: InputStream) {
        let bufSize = 4096
        self = ByteBufferAllocator().buffer(capacity: bufSize)
        var buf = [UInt8](repeating: 0, count: bufSize)
        while input.hasBytesAvailable {
            let result = input.read(&buf, maxLength: bufSize)
            if result < 0 {
                break
            }
            if result == 0 {
                break
            }
            self.writeBytes(buf[..<result])
        }
    }

    mutating private func indexOf(delim: Character) -> Array<UInt8>.Index? {
        var pos = self.readerIndex
        let bufSize = 4096
        let char = delim.asciiValue!
        while self.readableBytes > 0 {
            let length = (bufSize <= self.readableBytes ? bufSize : self.readableBytes)
            guard let bytes = self.getBytes(at: pos, length: length) else {
                return nil
            }
            guard let index = bytes.firstIndex(of: char) else {
                pos += bufSize
                continue
            }
            return index+1
        }
        return nil
    }

    /// Read the buffer until `delim` is found, move the reader index forward by the length of the data
    /// and return the result as `[UInt8]`, or `nil` if `delim` was not found.
    mutating func readBytes(until delim: Character) -> [UInt8]? {
        guard let index = self.indexOf(delim: delim) else {
            return self.readBytes(length: self.readableBytes)
        }
        return self.readBytes(length: index)
    }

    /// Read the buffer until `delim` is found, decoding is as String using the UTF-8 encoding.
    /// The reader index is moved forward by the length of the string found.
    mutating func readString(until delim: Character) -> String? {
        guard let index = self.indexOf(delim: delim) else {
            return self.readString(length: self.readableBytes)
        }
        return self.readString(length: index)
    }
}
