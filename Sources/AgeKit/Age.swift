import Foundation
import CryptoKit

/// An Identity is passed to `decrypt` to unwrap an opaque file key from a
/// recipient stanza. It can be for example a secret key like X25519Identity,
/// a plugin, or a custom implementation.
///
/// Most age API users won't need to interact with this directly, and should
/// instead pass  implementations conforming to`Recipient` to `encrypt`
/// and implementations conforming to `Identity` to `decrypt`.
public protocol Identity {
    func unwrap(stanzas: [Age.Stanza]) throws -> SymmetricKey
}

/// A Recipient is passed to `encrypt` to wrap an opaque file key to one or more
/// recipient stanza(s). It can be for example a public key like X25519Recipient.
/// a plugin, or a custom implementation.
///
/// Most age API users won't need to interact with this directly, and should
/// instead pass Recipient implementations to `encrypt` and implementations
/// conforming to `Identity`.
public protocol Recipient {
    func wrap(fileKey: SymmetricKey) throws -> [Age.Stanza]
}

// MARK: -

public enum Age {
    static let fileKeySize = 16
    static let streamNonceSize = 16


    /// A Stanza is a section of the age header that encapsulates the file key as
    /// encrypted to a specific recipient.
    ///
    /// Most age API users won't need to interact with this directly, and should
    /// instead pass Recipient implementations to `encrypt` and implementations
    /// conforming to `Identity`.
    public struct Stanza {
        var type: String
        var args: [String]
        var body: Data

        init() {
            self.type = ""
            self.args = []
            self.body = Data()
        }

        init(type: String, args: [String], body: Data?) {
            self.type = type
            self.args = args
            self.body = body ?? Data()
        }

        init(_ s: Format.Stanza) {
            self.type = s.type
            self.args = s.args
            self.body = s.body
        }
    }
}

// MARK: - Encrypt

extension Age {
    public enum EncryptError: Error {
        case noRecipients
        case scryptRecipientMustBeOnlyOne
        case nonceGeneration
        case nonceWrite(Error)
    }

    /// Encrypt a file to one or more recipients.
    ///
    /// Writes to the returned `StreamWriter` are encrypted and written to `dst` as an age file.
    /// Every recipient will be able to decrypt the file.
    ///
    /// The caller must call `close()` on the `StreamWriter` when done for the last chunk to
    /// be encrypted and flushed to `dst`.
    public static func encrypt(dst: inout OutputStream, recipients: Recipient...) throws -> StreamWriter {
        guard !recipients.isEmpty else {
            throw EncryptError.noRecipients
        }

        for r in recipients {
            if ((r as? ScryptRecipient) != nil) && recipients.count != 1 {
                throw EncryptError.scryptRecipientMustBeOnlyOne
            }
        }

        let fileKey = SymmetricKey(size: .bits128)

        var hdr = Format.Header()
        for r in recipients {
            let stanzas = try r.wrap(fileKey: fileKey)
            for s in stanzas {
                hdr.recipients.append(Format.Stanza(s))
            }
        }
        hdr.mac = try headerMAC(fileKey: fileKey, hdr: hdr)
        try hdr.encode(to: &dst)

        var nonce = [UInt8](repeating: 0, count: streamNonceSize)
        let status = SecRandomCopyBytes(kSecRandomDefault, nonce.count, &nonce)
        guard status == errSecSuccess else {
            throw EncryptError.nonceGeneration
        }

        _ = try dst.write(Data(nonce))
        if let streamError = dst.streamError {
            throw EncryptError.nonceWrite(streamError)
        }

        return StreamWriter(fileKey: streamKey(fileKey: fileKey, nonce: nonce), dst: dst)
    }
}

// MARK: - Decrypt

extension Age {
    public enum DecryptError: Error {
        case incorrectIdentity
        case noIdentities
        case computingHeaderMAC
        case badHeaderMAC
        case nonceRead(Error)
    }

    /// Decrypts a file encrypted to one or more identities.
    ///
    /// It returns a `StreamReader` for reading the decrypted plaintext of the age file read
    /// from `src`. All identities will be tried until one successfully decrypts the file.
    public static func decrypt(src: InputStream, identities: Identity...) throws -> StreamReader {
        if identities.isEmpty {
            throw DecryptError.noIdentities
        }

        let (hdr, payload) = try Format.parse(input: src)
        var stanzas: [Stanza] = []
        for s in hdr.recipients {
            stanzas.append(Stanza(s))
        }
        var fileKey: SymmetricKey?
        for id in identities {
            do {
                fileKey = try id.unwrap(stanzas: stanzas)
            } catch DecryptError.incorrectIdentity {
                continue
            } catch {
                throw error
            }
            break
        }
        guard let fileKey else {
            throw DecryptError.noIdentities
        }

        let mac = try headerMAC(fileKey: fileKey, hdr: hdr)
        if mac != hdr.mac {
            throw DecryptError.badHeaderMAC
        }

        var nonce = [UInt8](repeating: 0, count: streamNonceSize)
        payload.read(&nonce, maxLength: streamNonceSize)

        return StreamReader(
            fileKey: streamKey(fileKey: fileKey, nonce: nonce),
            src: payload)
    }

    static func multiUnwrap(stanzas: [Stanza], unwrap: (Stanza) throws -> SymmetricKey) throws -> SymmetricKey {
        for stanza in stanzas {
            do {
                let fileKey = try unwrap(stanza)
                return fileKey
            } catch DecryptError.incorrectIdentity {
                continue
            } catch {
                throw error
            }
        }

        throw DecryptError.incorrectIdentity
    }
}
