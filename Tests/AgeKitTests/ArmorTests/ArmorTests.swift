import XCTest
import Foundation
import SwiftASN1
@testable import AgeKit

final class ArmorTests: XCTestCase {
    func testArmorPartialLine() {
        XCTAssertNoThrow(try armor(size: 611))
    }

    func testArmorFullLine() {
        XCTAssertNoThrow(try armor(size: 10*Format.bytesPerLine))
    }

    func armor(size: Int) throws {
        let out = OutputStream.toMemory()
        out.open()
        var w = Armor.Writer(dst: out)
        var plain = [UInt8](repeating: 0, count: size)
        _ = SecRandomCopyBytes(kSecRandomDefault, size, &plain)
        XCTAssertNoThrow(try w.write(Data(plain)))
        XCTAssertNoThrow(try w.close())
        out.close()
        let buf = out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        let pem = String(data: buf, encoding: .utf8)!

        let doc = try PEMDocument(pemString: pem)
        XCTAssertEqual(doc.type, "AGE ENCRYPTED FILE", "unexpected type")
        XCTAssertEqual(doc.derBytes, Data(plain), "PEM decoded value doesn't match")
        XCTAssertEqual(pem, PEMDocument(type: "AGE ENCRYPTED FILE", derBytes: doc.derBytes).pemString, "PEM re-encoded value doesn't match")

        let input = InputStream(data: buf)
        input.open()
        var readBuf = [UInt8]()
        readBuf.reserveCapacity(buf.count)
        var r = Armor.Reader(src: input)
        _ = try r.read(&readBuf)
        input.close()
        XCTAssertEqual(readBuf, plain)
    }
}
