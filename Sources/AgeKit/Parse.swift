import Foundation
import NIOCore

extension Age {
    enum ParseError: Error {
        case malformedInput
        case parseErrorAtLine(Int)
        case noSecretKeysFound
    }

    /// Parses a file with one or more private key encodings, one per line.
    /// Empty lines and lines starting with "#" are ignored.
    public static func parseIdentities(input: InputStream) throws -> [Identity] {
        var ids: [Identity] = []
        var buf = ByteBuffer(input)

        var n = 0
        while buf.readableBytes > 0 {
            n += 1
            guard var line = buf.readString(until: "\n") else {
                throw ParseError.malformedInput
            }
            line = line.trimmingCharacters(in: .newlines)
            if line.hasPrefix("#") || line.isEmpty {
                continue
            }
            guard let id = try X25519Identity(line) else {
                throw ParseError.parseErrorAtLine(n)
            }
            ids.append(id)
        }
        guard !ids.isEmpty else {
            throw ParseError.noSecretKeysFound
        }
        return ids
    }
}
