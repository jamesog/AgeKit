import Foundation

extension OutputStream {
    func write(_ s: String) throws -> Int {
        if s.isEmpty { return 0 }
        let bytes = [UInt8](s.utf8)
        let ret = write(bytes, maxLength: bytes.count)
        if let streamError = streamError {
            throw streamError
        }
        return ret
    }

    func write(_ d: Data) throws -> Int {
        if d.isEmpty { return 0 }
        let buf: [UInt8] = Array(d)
        let ret = write(buf, maxLength: buf.count)
        if let streamError = streamError {
            throw streamError
        }
        return ret
    }
}
