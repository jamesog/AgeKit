import Foundation
import XCTest
import AgeKit  // public API only — exactly what a library user can call

/// The STREAM payload is split into 64 KiB chunks, and `Nonce.increment()` runs once per
/// chunk (including the last). Its 11-byte counter must carry from byte to byte; a checked
/// `UInt8 += 1` traps instead of carrying on the 256th increment — i.e. any payload larger
/// than 255 * 64 KiB = 16,711,680 bytes.
final class LargePayloadTests: XCTestCase {
    static let chunk = 64 * 1024

    /// 255 increments: the low byte reaches 0xff but never wraps. Expected to pass.
    func testRoundTripJustUnderBoundary() throws {
        try roundTrip(length: 255 * Self.chunk)
    }

    /// 256 increments: the low byte wraps. Expected to pass; traps if the carry is broken.
    func testRoundTripJustOverBoundary() throws {
        try roundTrip(length: 255 * Self.chunk + 1)
    }

    private func roundTrip(length: Int) throws {
        var plaintext = Data(count: length)
        plaintext.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) }
        let identity = Age.X25519Identity.generate()

        var out: OutputStream = .toMemory()
        out.open()
        var writer = try Age.encrypt(dst: &out, recipients: identity.recipient)
        var input = plaintext
        _ = try writer.write(&input)
        try writer.close()
        out.close()
        let ciphertext = out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data

        let src = InputStream(data: ciphertext)
        src.open()
        var reader = try Age.decrypt(src: src, identities: identity)
        var recovered = Data()
        var buf = Data(count: Self.chunk)
        while recovered.count < length {
            let n = try reader.read(&buf)
            recovered.append(buf.prefix(n))
        }
        XCTAssertEqual(recovered, plaintext)
    }
}
