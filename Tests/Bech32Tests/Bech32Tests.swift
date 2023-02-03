import XCTest
@testable import Bech32

final class Bech32Tests: XCTestCase {
    func testBech32() {
        let tests: [(str: String, valid: Bool)] = [
            ("A12UEL5L", true), // empty
            ("a12uel5l", true),
            ("an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs", true),
            ("abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw", true),
            ("11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j", true),
            ("split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", true),

            // invalid checksum
            ("split1checkupstagehandshakeupstreamerranterredcaperred2y9e2w", false),
            // invalid character (space) in hrp
            ("s lit1checkupstagehandshakeupstreamerranterredcaperredp8hs2p", false),
            ("split1cheo2y9e2w", false), // invalid character (o) in data part
            ("split1a2y9w", false),      // too short data part
            ("1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", false), // empty hrp
            // invalid character (DEL) in hrp
            ("spl" + String(Character(UnicodeScalar(127))) + "t1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", false),

            // long vectors that we do accept despite the spec, see Issue 453
            ("long10pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7rc0pu8s7qfcsvr0", true),
            ("an84characterslonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1569pvx", true),

            // BIP 173 invalid vectors.
            ("pzry9x0s0muk", false),
            ("1pzry9x0s0muk", false),
            ("x1b4n0q5v", false),
            ("li1dgmt3", false),
            ("de1lg7wt\u{ff}", false),
            ("A1G7SGD8", false),
            ("10a06t8", false),
            ("1qzzfhee", false),
        ]

        for test in tests {
            let str = test.str
            if !test.valid {
                XCTAssertThrowsError(try Bech32.decode(from: str))
                continue
            }

            let (hrp, decoded) = try! Bech32.decode(from: str)
            let encoded = try! Bech32.encode(to: hrp, data: decoded)
            XCTAssertEqual(encoded, str)

        }
    }
}
