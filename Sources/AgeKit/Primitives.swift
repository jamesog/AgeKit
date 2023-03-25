import CryptoKit
import Foundation

// MARK: - AEAD Encrypt

extension Age {
    ///  Encrypt a message with a one-time key.
    static func aeadEncrypt(key: SymmetricKey, plaintext: SymmetricKey) throws -> Data {
        let p = plaintext.withUnsafeBytes { Data(Array($0)) }
        // The nonce is fixed because this function is only used in places where the
        // spec guarantees each key is only used once (by deriving it from values
        // that include fresh randomness), allowing us to save the overhead.
        // For the code that encrypts the actual payload, look at the `Stream` types.
        let nonce = try ChaChaPoly.Nonce(data: Data(repeating: 0, count: ChaChaPoly.nonceSize))
        // CryptoKit's combined property contains all of nonce+ciphertext+tags.
        // For compatibility with other languages we need to exclude the nonce.
        return try ChaChaPoly.seal(p, using: key, nonce: nonce).combined.dropFirst(ChaChaPoly.nonceSize)
    }

    static func aeadEncrypt(key: [UInt8], plaintext: SymmetricKey) throws -> Data {
        let k = SymmetricKey(data: key)
        return try aeadEncrypt(key: k, plaintext: plaintext)
    }
}

// MARK: - AEAD Decrypt

extension Age {
    enum AEADError: Error {
        case incorrectCiphertextSize
    }

    /// Decrypt a message of an expected fixed size.
    ///
    /// The message size is limited to mitigate multi-key attacks, where a ciphertext
    /// can be crafted that decrypts successfully under multiple keys. Short ciphertexts
    /// can only target two keys, which has limited impact.
    static func aeadDecrypt(key: SymmetricKey, size: Int, ciphertext: Data) throws -> Data {
        let nonce = try ChaChaPoly.Nonce(data: Data(repeating: 0, count: ChaChaPoly.nonceSize))
        let box = try ChaChaPoly.SealedBox(combined: nonce+ciphertext)
        guard ciphertext.count == size+ChaChaPoly.overhead else {
            throw AEADError.incorrectCiphertextSize
        }
        return try ChaChaPoly.open(box, using: key)
    }

    static func aeadDecrypt(key: [UInt8], size: Int, ciphertext: Data) throws -> Data {
        let aead = SymmetricKey(data: key)
        return try aeadDecrypt(key: aead, size: size, ciphertext: ciphertext)
    }
}

// MARK: -

extension Age {
    static func headerMAC(fileKey: SymmetricKey, hdr: Format.Header) throws -> Data {
        let h = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: fileKey,
            info: "header".data(using: .utf8)!,
            outputByteCount: SHA256.byteCount)
        var hh = HMAC<SHA256>(key: h)
        hdr.encodeWithoutMAC(to: &hh)
        return Data(hh.finalize())
    }

    static func streamKey(fileKey: SymmetricKey, nonce: ContiguousBytes) -> SymmetricKey {
        let b = nonce.withUnsafeBytes { bytes in
            Data(Array(bytes))
        }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: fileKey,
            salt: b,
            info: "payload".data(using: .utf8)!,
            outputByteCount: SHA256.byteCount)
    }
}
