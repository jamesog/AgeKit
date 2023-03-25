import XCTest
@testable import AgeKit

var helloWorld = "Hello, Twitch!".data(using: .utf8)!

final class AgeKitTests: XCTestCase {
    func testEncryptDecryptScrypt() throws {
        let password = "twitch.tv/filosottile"

        var r = Age.ScryptRecipient(password: password)!
        r.setWorkFactor(15)
        var buf = OutputStream.toMemory()
        buf.open()
        var w = try Age.encrypt(dst: &buf, recipients: r)
        var p = helloWorld
        _ = try w.write(&p)
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
        let want = String(data: helloWorld, encoding: .utf8)!
        XCTAssertEqual(got, want)
    }
}
