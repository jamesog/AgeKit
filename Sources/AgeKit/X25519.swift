import Bech32
import CryptoKit
import ExtrasBase64
import Foundation

let x25519Label = "age-encryption.org/v1/X25519"

// MARK: - Recipient

extension Age {
    /// X25519Recipient is the standard age public key. Messages encrypted to this
    /// recipient can be decrypted with the corresponding `X25519Identity`.
    ///
    /// This recipient is anonymous, in the sense that an attacker can't tell from
    /// the message alone if it is encrypted to a certain recipient.
    public struct X25519Recipient: Recipient {
        enum Error: Swift.Error {
            case invalidType
            case invalidPublicKey
        }

        private let theirPublicKey: Curve25519.KeyAgreement.PublicKey

        /// The Bech32 public key encoding of the recipient.
        public var string: String {
            try! Bech32.encode(to: "age", data: theirPublicKey.rawRepresentation)
        }

        /// Create an X25519Recipient from a Bech32-encoded public key with the "age1" prefix.
        init(_ string: String) throws {
            let (hrp, data) = try Bech32.decode(from: string)
            if hrp != "age" {
                throw Error.invalidType
            }
            try self.init(data)
        }

        fileprivate init(_ publicKey: Data) throws {
            guard publicKey.count == Curve25519.pointSize else {
                throw Error.invalidPublicKey
            }
            self.theirPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        }

        public func wrap(fileKey: SymmetricKey) throws -> [Stanza] {
            let ephemeral = Curve25519.KeyAgreement.PrivateKey()
            let ourPublicKey = ephemeral.publicKey.rawRepresentation
            let sharedSecret = try ephemeral.sharedSecretFromKeyAgreement(with: theirPublicKey)

            let salt = Data(ourPublicKey + theirPublicKey.rawRepresentation)

            let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: salt,
                sharedInfo: x25519Label.data(using: .utf8)!,
                outputByteCount: SHA256.byteCount)
            let wrappedKey = try aeadEncrypt(key: wrappingKey, plaintext: fileKey)
            let b64 = Base64.encodeString(bytes: ourPublicKey, options: .omitPaddingCharacter)
            let stanza = Stanza(
                type: "X25519",
                args: [b64],
                body: wrappedKey
            )

            return [stanza]
        }
    }
}

// MARK: - Identity

extension Age {
    /// X25519Identity is the standard age private key, which can decrypt messages
    /// encrypted to the corresponding `X25519Recipient`.
    public struct X25519Identity: Identity {
        enum Error: Swift.Error {
            case malformedSecretKey
            case incorrectIdentity
            case invalidX25519RecipientBlock
        }

        private let secretKey: Curve25519.KeyAgreement.PrivateKey

        /// The Bech32 private key encoding of the identity.
        public var string: String {
            try! Bech32.encode(to: "AGE-SECRET-KEY-", data: secretKey.rawRepresentation).uppercased()
        }

        /// The public `X25519Recipient` value corresponding to this identity.
        public var recipient: X25519Recipient {
            try! X25519Recipient(secretKey.publicKey.rawRepresentation)
        }

        private init(secretKey: Curve25519.KeyAgreement.PrivateKey) {
            self.secretKey = secretKey
        }

        /// Create an X25519Identity from a Bech32-encoded private key with the "AGE-SECRET-KEY-1" prefix.
        ///
        /// - Throws: `Error.malformedSecretKey` when the key is incorrectly formatted.
        init?(_ string: String) throws {
            let (hrp, data) = try Bech32.decode(from: string)
            if hrp != "AGE-SECRET-KEY-" {
                throw Error.malformedSecretKey
            }
            self.secretKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        }

        /// Randomly generate a new `X25519Identity`.
        public static func generate() -> X25519Identity {
            let secretKey = Curve25519.KeyAgreement.PrivateKey()
            return X25519Identity(secretKey: secretKey)
        }

        public func unwrap(stanzas: [Stanza]) throws -> SymmetricKey {
            return try multiUnwrap(stanzas: stanzas) { block in
                guard block.type == "X25519" else {
                    throw DecryptError.incorrectIdentity
                }
                guard block.args.count == 1 else {
                    throw Error.invalidX25519RecipientBlock
                }
                let rawPubKey = try Base64.decode(string: block.args[0], options: .omitPaddingCharacter)
                let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(rawPubKey))
                guard publicKey.rawRepresentation.count == Curve25519.pointSize else {
                    throw Error.invalidX25519RecipientBlock
                }

                let sharedSecret = try secretKey.sharedSecretFromKeyAgreement(with: publicKey)

                // FIXME: publicKey and secretKey.publicKey are the same?
                let salt = Data(publicKey.rawRepresentation + secretKey.publicKey.rawRepresentation)
                let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
                    using: SHA256.self,
                    salt: salt,
                    sharedInfo: x25519Label.data(using: .utf8)!,
                    outputByteCount: SHA256.byteCount)

                do {
                    let fileKey = try aeadDecrypt(key: wrappingKey, size: fileKeySize, ciphertext: block.body)
                    return SymmetricKey(data: fileKey)
                } catch {
                    throw DecryptError.incorrectIdentity
                }

            }
        }
    }
}
