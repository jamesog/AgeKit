import Foundation

private let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l".data(using: .utf8)!
private let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]

enum EncodeError: Error {
    case invalidHRP, invalidCharacter, mixedCase
}

enum DecodeError: Error {
    case mixedCase, invalidPosition, invalidCharacter, invalidChecksum
}

enum ConvertError: Error {
    case invalidDataRange, illegalZeroPadding, nonZeroPadding
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

private func convertBits(data: Data, fromBits: UInt8, toBits: UInt8, pad: Bool) throws -> Data {
    var ret = Data()
    var acc = UInt32(0)
    var bits = UInt8(0)
    let maxv = UInt8(1<<toBits - 1)
    for value in data {
        if value>>fromBits != 0 {
            throw ConvertError.invalidDataRange
        }
        acc = acc<<fromBits | UInt32(value)
        bits += fromBits
        while bits >= toBits {
            bits -= toBits
            ret.append(UInt8(truncatingIfNeeded: acc>>bits)&maxv)
        }
    }
    if pad, bits > 0 {
        ret.append(UInt8(truncatingIfNeeded: acc<<(toBits-bits))&maxv)
    } else if bits >= fromBits {
        throw ConvertError.illegalZeroPadding
    }
    return ret
}

public func encode(to hrp: String, data: Data) throws -> String {
    let values = try convertBits(data: data, fromBits: 8, toBits: 5, pad: true)
    var ret = hrp.data(using: .utf8)!
    ret.append("1".data(using: .utf8)!)
    for i in values {
        ret.append(charset[Int(i)])
    }
    for i in createChecksum(for: hrp, data: values) {
        ret.append(charset[Int(i)])
    }
    let s = String(data: ret, encoding: .utf8)!
    return hrp.lowercased() == hrp ? s : s.uppercased()
}

public func decode(from: String) throws -> (hrp: String, data: Data) {
    if from.lowercased() != from && from.uppercased() != from {
        throw DecodeError.mixedCase
    }
    let str = from.data(using: .utf8)!
    guard let marker = from.lastIndex(of: "1") else {
        throw DecodeError.invalidPosition
    }

    let pos = from.distance(from: from.startIndex, to: marker)
    if pos < 1 || pos+7 > from.count {
        throw DecodeError.invalidPosition
    }
    let hrp = str[..<pos]
    for p in hrp {
        if p < 33 || p > 126 {
            throw DecodeError.invalidCharacter
        }
    }

    var data = Data()
    let s = from.lowercased().data(using: .utf8)!
    for c in s[(pos+1)...] {
        guard let i = charset.firstIndex(of: c) else { throw DecodeError.invalidCharacter }
        data.append(UInt8(i))
    }
    if !verifyChecksum(hrp: String(data: hrp, encoding: .utf8)!, data: data) {
        throw DecodeError.invalidChecksum
    }

    data = try convertBits(data: data[0..<data.count-6], fromBits: 5, toBits: 8, pad: false)
    return (String(data: hrp, encoding: .utf8)!, data)
}
