import Foundation

private let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l".data(using: .utf8)!
private let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]

enum EncodeError: Error {
    case InvalidHRP, InvalidCharacter, MixedCase
}

enum DecodeError: Error {
    case MixedCase, InvalidPosition, InvalidCharacter, InvalidChecksum
}

enum ConvertError: Error {
    case InvalidDataRange, IllegalZeroPadding, NonZeroPadding
}

private func polymod(_ values: Data) -> UInt32 {
    var chk = UInt32(1)
    values.forEach { v in
        let top = chk >> 25
        chk = (chk & 0x1ffffff) << 5
        chk = chk ^ UInt32(v)
        for i in 0..<5 {
            chk ^= ((top >> i) & 1) == 0 ? 0 : generator[i]
        }
    }
    return chk
}

private func expandHrp(for hrp: String) -> Data {
    guard let h = hrp.lowercased().data(using: .utf8) else { return Data() }
    return Data(h.map { $0 >> 5 } + [UInt8(0)] + h.map { $0 & 31 })
}

private func verifyChecksum(hrp: String, data: Data) -> Bool {
    var h = expandHrp(for: hrp)
    h.append(data)
    return polymod(h) == 1
}

private func createChecksum(for hrp: String, data: Data) -> Data {
    var values = expandHrp(for: hrp)
    values.append(contentsOf: data)
    values.append(contentsOf: Array(repeating: UInt8(0), count: 6))
    let mod = polymod(values) ^ 1
    var data = Data()
    for i in (0..<6) {
        let shift = 5 * (5 - i)
        data.append(UInt8(truncatingIfNeeded: mod >> shift) & 31)
    }
    return data
}

public func encode(to hrp: String, data: Data) throws -> String {
    var data = data
    data.append(createChecksum(for: hrp, data: data))
    let bytes = Data(data.map { i in
        charset[charset.index(Data.Index(i), offsetBy: 0)]
    })
    let s = String(data: bytes, encoding: .utf8)!
    let ret = "\(hrp)1\(s)"
    return hrp.lowercased() == hrp ? ret : ret.uppercased()
}

public func decode(from: String) throws -> (hrp: String, data: Data) {
    if from.lowercased() != from && from.uppercased() != from {
        throw DecodeError.MixedCase
    }
    let str = from.data(using: .utf8)!
    guard let marker = from.lastIndex(of: "1") else {
        throw DecodeError.InvalidPosition
    }

    let pos = from.distance(from: from.startIndex, to: marker)
    if pos < 1 || pos+7 > from.count {
        throw DecodeError.InvalidPosition
    }
    let hrp = str[..<pos]
    for p in hrp {
        if p < 33 || p > 126 {
            throw DecodeError.InvalidCharacter
        }
    }

    var data = Data()
    let s = from.lowercased().data(using: .utf8)!
    for c in s[(pos+1)...] {
        guard let i = charset.firstIndex(of: c) else { throw DecodeError.InvalidCharacter }
        data.append(UInt8(i))
    }
    if !verifyChecksum(hrp: String(data: hrp, encoding: .utf8)!, data: data) {
        throw DecodeError.InvalidChecksum
    }

    return (String(data: hrp, encoding: .utf8)!, data[0..<data.count-6])
}
