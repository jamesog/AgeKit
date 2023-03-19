import CryptoKit
import XCTest
@testable import AgeKit

/// The tests are run from `StreamTests_gen.swift`.
/// To generate the tests run:
/// ```
/// ./gyb --line-directive '' - oStreamTests_gen.swift Tests/AgeKitTests/StreamTests/StreamTests.swift.gyb
/// ```
/// from the root of the repo.
extension StreamTests {
    func roundTrip(stepSize: Int, length: Int) throws {
        var src = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, src.count, &src)

        let key = SymmetricKey(size: .bits256)
        let out = OutputStream.toMemory()
        out.open()

        var w = StreamWriter(fileKey: key, dst: out)

        var n = 0
        while n < length {
            var b = length - n
            if b > stepSize {
                b = stepSize
            }
            var d = Data(src[n..<n+b])
            var nn = try w.write(&d)
            XCTAssertEqual(nn, b, "write returned \(nn), expected \(b)")
            n += nn

            d = Data(src[n..<n])
            nn = try w.write(&d)
            XCTAssertEqual(nn, 0, "write returned \(nn), expected 0")
        }

        try w.close()
        out.close()

        let buf = out.property(forKey: .dataWrittenToMemoryStreamKey) as? Data ?? Data()

         let input = InputStream(data: buf)
         input.open()
         var r = StreamReader(fileKey: key, src: input)

         n = 0
         var readBuf = Data(repeating: 0, count: stepSize)
         while n < length {
             let nn = try r.read(&readBuf)
             XCTAssertEqual(readBuf[..<nn], Data(src[n..<n+nn]), "wrong data in indexes \(n) - \(n+nn)")
             n += nn
         }
    }
}
