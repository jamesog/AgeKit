import Foundation

extension Data {
    var bytes: [UInt8] {
        Array(self)
    }
}

extension String {
    public var bytes: [UInt8] {
        data(using: String.Encoding.utf8, allowLossyConversion: true)?.bytes ?? Array(utf8)
    }
}
