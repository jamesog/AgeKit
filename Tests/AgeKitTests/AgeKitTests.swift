import XCTest
@testable import AgeKit

var helloWorld = "Hello, Twitch!"

final class AgeKitTests: XCTestCase {

    func testEncryptDecryptX25519() throws {
        let a = Age.X25519Identity.generate()
        let b = Age.X25519Identity.generate()
        var out = OutputStream.toMemory()
        out.open()
       var w = try Age.encrypt(dst: &out, recipients: a.recipient, b.recipient)
        _ = try w.write(helloWorld)
        try w.close()
        out.close()
        let buf = out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data

        let input = InputStream(data: buf)
        input.open()
        var r = try Age.decrypt(src: input, identities: b)
        var result = Data(repeating: 0, count: 1024)
        _ = try r.read(&result)
        input.close()
        XCTAssertEqual(String(data: result, encoding: .utf8)!, helloWorld)
    }


    func testEncryptDecryptScrypt() throws {
        let password = "twitch.tv/filosottile"

        var r = Age.ScryptRecipient(password: password)!
        r.setWorkFactor(15)
        var buf = OutputStream.toMemory()
        buf.open()
        var w = try Age.encrypt(dst: &buf, recipients: r)
        _ = try w.write(helloWorld)
        try w.close()
        buf.close()
        let bufBytes = buf.property(forKey: .dataWrittenToMemoryStreamKey) as! Data

        let i = Age.ScryptIdentity(password)!
        let input = InputStream(data: bufBytes)
        input.open()
        var out = try Age.decrypt(src: input, identities: i)
        input.close()
        var outBytes = Data(repeating: 0, count: bufBytes.count)
        _ = try out.read(&outBytes)

        let got = String(data: outBytes, encoding: .utf8)!
        XCTAssertEqual(got, helloWorld)
    }
}
