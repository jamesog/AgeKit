import Foundation

extension InputStream {
    func readLine(delimiter: String = "\n") throws -> Data? {
        let bufferSize = 1024
        let delimiter = delimiter.data(using: .utf8)!

        var buffer = Data(capacity: bufferSize)
        var delimiterRange = buffer.range(of: delimiter)

        while delimiterRange == nil {
            if self.read(&buffer, maxLength: bufferSize) < 0 {
                throw streamError!
            }
            if buffer.count == 0 {
                return nil
            }
            delimiterRange = buffer.range(of: delimiter)
        }

        let lineRange = 0..<delimiterRange!.upperBound
        let line = buffer.subdata(in: lineRange)

        return line
    }
}
