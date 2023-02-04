import Foundation

extension Data {
    func readLine(delimiter: String = "\n") -> Data? {
        let delimiter = delimiter.data(using: .utf8)!
        let delimiterRange = self.range(of: delimiter)
        let lineRange = 0..<delimiterRange!.upperBound
        return self.subdata(in: lineRange)
    }
}
