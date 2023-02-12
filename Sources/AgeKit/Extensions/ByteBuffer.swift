import Foundation
import NIOCore

extension ByteBuffer {
    /// Create a fresh ByteBuffer from the given `InputStream`.
    ///
    /// The entire `InputStream` is consumed into the buffer.
    init(_ input: InputStream) {
        var buf = [UInt8](repeating: 0, count: 4096)
        while input.hasBytesAvailable {
            let result = input.read(&buf, maxLength: buf.count)
            if result < 0 {
                break
            }
            if result == 0 {
                break
            }
        }
        self = ByteBufferAllocator().buffer(bytes: buf)
    }

    /// Read the buffer until `delim` is found, move the reader index forward by the length of the data
    /// and return the result as `[UInt8]`, or `nil` if `delim` was not found.
    mutating func readBytes(until delim: Character) -> [UInt8]? {
        var pos = self.readerIndex
        let bufSize = 4096
        let char = delim.asciiValue!
        while self.readableBytes >= pos {
            let length = (bufSize <= self.readableBytes ? bufSize : self.readableBytes)
            guard let b = self.getBytes(at: pos, length: length) else {
                return nil
            }
            guard let i = b.firstIndex(of: char) else {
                pos += bufSize
                continue
            }
            return self.readBytes(length: i+1)
        }
        return nil
    }

    /// Read the buffer until `delim` is found, decoding is as String using the UTF-8 encoding.
    /// The reader index is moved forward by the length of the string found.
    mutating func readString(until delim: Character) -> String? {
        var pos = self.readerIndex
        let bufSize = 4096
        let char = delim.asciiValue!
        while self.readableBytes >= pos {
            let length = (bufSize <= self.readableBytes ? bufSize : self.readableBytes)
            guard let b = self.getBytes(at: pos, length: length) else {
                return nil
            }
            guard let i = b.firstIndex(of: char) else {
                pos += bufSize
                continue
            }
            return self.readString(length: i+1)
        }
        return nil
    }
}
