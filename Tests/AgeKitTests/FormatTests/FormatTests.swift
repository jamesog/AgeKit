import XCTest
import Foundation
@testable import AgeKit

final class FormatTests: XCTestCase {
    func testStanzaEncodeEmptyBody() throws {
        var s = Format.Stanza()
        s.type = "test"
        s.args = ["1", "2", "3"]

        let expect = "-> test 1 2 3\n\n"

        var out = OutputStream.toMemory()
        out.open()
        try s.encode(to: &out)
        out.close()
        XCTAssertNil(out.streamError)
        let buf = out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        let str = String(bytes: buf, encoding: .utf8)!
        XCTAssertEqual(str, expect, "wrong empty stanza encoding")
    }

    func testStanzaEncodeNormalBody() throws {
        var s = Format.Stanza()
        s.type = "test"
        s.args = ["1", "2", "3"]
        s.body = "AAA".data(using: .utf8)!

        let expect = "-> test 1 2 3\nQUFB\n"

        var out = OutputStream.toMemory()
        out.open()
        _ = try s.encode(to: &out)
        out.close()
        XCTAssertNil(out.streamError)
        let buf = out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        let str = String(bytes: buf, encoding: .utf8)!
        XCTAssertEqual(str, expect, "wrong normal stanza encoding")
    }

    func testStanzaEncodeLongBody() throws {
        var s = Format.Stanza()
        s.type = "test"
        s.args = ["1", "2", "3"]
        s.body = String(repeating: "A", count: Format.bytesPerLine).data(using: .utf8)!

        let expect = "-> test 1 2 3\nQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFB\n\n"

        var out = OutputStream.toMemory()
        out.open()
        _ = try s.encode(to: &out)
        out.close()
        XCTAssertNil(out.streamError)
        let buf = out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        let str = String(bytes: buf, encoding: .utf8)!
        XCTAssertEqual(str, expect, "wrong 64 columns stanza encoding")
    }
}
