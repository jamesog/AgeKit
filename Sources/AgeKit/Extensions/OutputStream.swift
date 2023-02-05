import Foundation

extension OutputStream {
    func write(_ s: String) throws {
        let bytes = [UInt8](s.utf8)
        write(bytes, maxLength: bytes.count)
        if let streamError = streamError {
            throw streamError
        }
    }

    func write(_ d: Data) throws {
        if d.isEmpty { return }
        let buf: [UInt8] = Array(d)
        write(buf, maxLength: buf.count)
        if let streamError = streamError {
            throw streamError
        }
    }
}
