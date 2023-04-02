import CryptoKit
import Foundation
import Scrypt

let scryptLabel = "age-encryption.org/v1/scrypt".data(using: .utf8)!
let scryptSaltSize = 16

// MARK: - Recipient

extension Age {
    /// A password-based recipient. Anyone with the password can decrypt the message.
    ///
    /// If an `ScryptRecipient` is used, it must be the only recipient for the file: it can't be mixed
    /// with other recipient types and can't be used multiple times for the same file.
    ///
    /// Its use is not recommended for automated systems, which should prefer `X25519Recipient`.
    public struct ScryptRecipient: Recipient {
        let password: Data
        var workFactor: Int

        /// Create a new `ScryptRecipient` with the provided password.
        public init?(password: String) {
            if password.isEmpty {
                return nil
            }
            self.password = password.data(using: .utf8)!
            self.workFactor = 18
        }

        enum WrapError: Error {
            case errSecSuccess(Int32)
        }

        /// Sets the scrypt work factor  to 2^logN. It must be called before `wrap`.
        ///
        /// This caps the amount of work that `Age.decrypt` might have to do to process
        /// received files. If `setWorkFactor` is not called, a fairly high default is used,
        /// which might not be suitable for systems processing untrsted files.
        public mutating func setWorkFactor(_ logN: Int) {
            assert(logN > 1 && logN < 30, "setWorkFactor called with illegal value")
            workFactor = logN
        }

        public func wrap(fileKey: SymmetricKey) throws -> [Age.Stanza] {
            var saltBytes = [UInt8](repeating: 0, count: scryptSaltSize)
            let status = SecRandomCopyBytes(kSecRandomDefault, scryptSaltSize, &saltBytes)
            guard status == errSecSuccess else {
                throw WrapError.errSecSuccess(errSecSuccess)
            }

            let args = [Data(saltBytes).base64EncodedString(), String(workFactor)]

            var salt = scryptLabel
            salt.append(saltBytes, count: saltBytes.count)

            let k = try scrypt(
                password: password.bytes,
                salt: salt.bytes,
                length: ChaChaPoly.keySize,
                N: 1<<workFactor,
                r: 8,
                p: 1)
            let wrappedKey = try aeadEncrypt(key: k, plaintext: fileKey)

            return [Age.Stanza(type: "scrypt", args: args, body: wrappedKey)]
        }
    }
}

// MARK: - Identity

extension Age {
    /// A password-based identity.
    public struct ScryptIdentity: Identity {
        private let password: Data
        private var maxWorkFactor: Int

        init?(_ password: String) {
            if password.isEmpty {
                return nil
            }
            self.password = password.data(using: .utf8)!
            self.maxWorkFactor = 22
        }

        enum Error: Swift.Error {
            case incorrectIdentity
            case invalidRecipient
            case invalidScryptWorkFactor
            case workFactorTooLarge
        }

        /// Sets the maximum accepted scrypt work factor to 2^logN. It must be called before `unwrap`.
        ///
        /// This caps the amount of work that `Age.decrypt` might have to do to process
        /// received files. If `setMaxWorkFactor` is not called, a fairly high default is used,
        /// which might not be suitable for systems processing untrsted files.
        public mutating func setMaxWorkFactor(_ logN: Int) {
            assert(logN > 1 && logN < 30, "setMaxWorkFactor called with illegal value")
            maxWorkFactor = logN
        }

        // TODO: Update this to use the new Regex type in Swift 5.7
        private let digitsRe = try! NSRegularExpression(pattern: "^[1-9][0-9]*$")

        public func unwrap(stanzas: [Age.Stanza]) throws -> SymmetricKey {
            return try multiUnwrap(stanzas: stanzas) { block in
                guard block.type == "scrypt" else {
                    throw DecryptError.incorrectIdentity
                }
                guard block.args.count == 2 else {
                    throw Error.invalidRecipient
                }

                var salt = try Format.decodeString(block.args[0])
                guard salt.count == scryptSaltSize else {
                    throw Error.invalidRecipient
                }

                let range = NSRange(location: 0, length: block.args[1].count)
                guard digitsRe.firstMatch(in: block.args[1], range: range) != nil else {
                    throw Error.invalidScryptWorkFactor
                }
                guard let logN = Int(block.args[1]), logN > 0 else {
                    throw Error.invalidScryptWorkFactor
                }
                guard logN <= maxWorkFactor else {
                    throw Error.workFactorTooLarge
                }

                salt = Data(scryptLabel.bytes + salt.bytes)
                let k = try scrypt(
                    password: Array(password),
                    salt: salt.bytes,
                    length: ChaChaPoly.keySize,
                    N: 1<<logN,
                    r: 8,
                    p: 1)
                let fileKey = try aeadDecrypt(key: k, size: fileKeySize, ciphertext: block.body)
                return SymmetricKey(data: fileKey)
            }
        }
    }
}
