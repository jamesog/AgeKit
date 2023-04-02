import CryptoKit
import ExtrasBase64
import Foundation
import NIOCore

public enum Format {
    static let intro = "age-encryption.org/v1\n"

    static let stanzaPrefix = "->".data(using: .utf8)!
    static let footerPrefix = "---".data(using: .utf8)!
}

// MARK: - Header

extension Format {
    public struct Header {
        var recipients: [Stanza] = []
        var mac = Data()

        public func encodeWithoutMAC<H: HashFunction>(to hash: inout HMAC<H>) {
            hash.update(data: Format.intro.data(using: .utf8)!)
            for r in self.recipients {
                hash.update(data: r.encode())
            }
            hash.update(data: Format.footerPrefix)
        }

        public func encodeWithoutMAC(to output: inout OutputStream) throws {
            _ = try output.write(Format.intro.data(using: .utf8)!)
            for r in self.recipients {
                try r.encode(to: &output)
            }
            _ = try output.write(Format.footerPrefix)
        }

        public func encode(to output: inout OutputStream) throws {
            try self.encodeWithoutMAC(to: &output)
            _ = try output.write(" ".data(using: .utf8)!)
            let b64 = Base64.encodeString(bytes: self.mac, options: .omitPaddingCharacter)
            _ = try output.write(b64)
            _ = try output.write("\n".data(using: .utf8)!)
        }
    }
}

// MARK: - Stanza

extension Format {
    static let columnsPerLine = 64
    static var bytesPerLine: Int { columnsPerLine / 4 * 3 }

    public struct Stanza {
        var type: String
        var args: [String]
        var body: Data

        init() {
            self.type = ""
            self.args = []
            self.body = Data()
        }

        init(_ s: Age.Stanza) {
            self.type = s.type
            self.args = s.args
            self.body = s.body
        }

        public func encode() -> Data {
            var out = OutputStream.toMemory()
            out.open()
            try! encode(to: &out)
            out.close()
            return out.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        }

        public func encode(to: inout OutputStream) throws {
            var stanza = String(data: Format.stanzaPrefix, encoding: .utf8)!
            var args = [type]
            args.append(contentsOf: self.args)
            for a in args {
                stanza.append(" \(a)")
            }
            stanza.append("\n")
            let b64 = Base64.encodeString(bytes: body, options: .omitPaddingCharacter)
            stanza.append(b64)
            // The format is a little finicky and requires some short lines.
            // When the input is divisible by bytesPerLine the encoder won't have
            // added the final newline the format expects.
            if self.body.count > 0 && self.body.count % Format.bytesPerLine == 0 {
                stanza.append("\n")
            }
            stanza.append("\n")
            _ = try to.write(stanza.data(using: .utf8)!)
        }
    }

    enum DecodeError: Error {
        case unexpectedNewLineError
    }

    public static func decodeString(_ s: String) throws -> Data {
        if #available(macOS 13.0, iOS 16.0, *) {
            if s.contains(["\n", "\r"]) {
                throw DecodeError.unexpectedNewLineError
            }
        } else {
            if s.contains("\n") || s.contains("\r") {
                throw DecodeError.unexpectedNewLineError
            }
        }
        let b64 = try Base64.decode(string: s, options: .omitPaddingCharacter)
        return Data(b64)
    }

    enum StanzaError: Error {
        case lineError
        case malformedOpeningLine
        case malformedStanza
        case malformedBodyLineSize
    }

    struct StanzaReader {
        var buf: ByteBuffer

        init(_ buf: ByteBuffer) {
            self.buf = buf
        }

        public mutating func readStanza() throws -> Stanza {
            var stanza = Stanza()

            guard let line = buf.readBytes(until: "\n") else {
                throw StanzaError.lineError
            }
            guard line.starts(with: stanzaPrefix) else {
                throw StanzaError.malformedOpeningLine
            }
            let (prefix, args) = splitArgs(line: line)
            guard prefix.bytes == stanzaPrefix.bytes && args.count >= 1 else {
                throw StanzaError.malformedStanza
            }
            for arg in args where !isValidString(arg) {
                throw StanzaError.malformedStanza
            }
            stanza.type = args[0]
            stanza.args = Array(args[1...])

            while true {
                guard let line = buf.readBytes(until: "\n") else {
                    throw StanzaError.lineError
                }

                var lineStr = String(bytes: line, encoding: .utf8)!
                lineStr = lineStr.trimmingCharacters(in: ["\n"])
                let b: Data
                do {
                    b = try decodeString(lineStr)
                    if b.count > bytesPerLine {
                        throw StanzaError.malformedBodyLineSize
                    }
                    stanza.body.append(b)
                    if b.count < bytesPerLine {
                        return stanza
                    }
                } catch {
                    // TODO: The Go implementation checks the value for the footerPrefix and stanzaPrefix
                }
            }
        }
    }

    enum ParseError: Error {
        case introRead
        case unexpectedIntro
        case readHeader
        case malformedClosingLine
        case internalError
    }

    public static func parse(input: InputStream) throws -> (Header, InputStream) {
        var header = Header()
        // Consume the entire input
        // FIXME: We shouldn't do this and should read chunks at a time
        var buf = ByteBuffer(input)

        guard let line = buf.readString(until: "\n") else {
            throw ParseError.introRead
        }
        guard line == Format.intro else {
            throw ParseError.unexpectedIntro
        }

        while true {
            guard let peek = buf.getBytes(at: buf.readerIndex, length: footerPrefix.count) else {
                throw ParseError.readHeader
            }
            if peek == Array(footerPrefix) {
                guard let line = buf.readBytes(until: "\n") else {
                    throw ParseError.readHeader
                }

                let (prefix, args) = splitArgs(line: line)
                if prefix != String(data: footerPrefix, encoding: .utf8)! || args.count != 1 {
                    throw ParseError.malformedClosingLine
                }
                header.mac = try decodeString(args[0])
                if header.mac.count != 32 {
                    throw ParseError.malformedClosingLine
                }
                break
            }

            var sr = StanzaReader(buf)
            let s = try sr.readStanza()
            buf = sr.buf // read buf back to get the position advances
            header.recipients.append(s)
        }

        guard let buf = buf.getBytes(at: buf.readerIndex, length: buf.readableBytes) else {
            throw ParseError.internalError
        }
        let payload = InputStream(data: Data(buf))
        payload.open()
        return (header, payload)
    }

    private static func splitArgs<Bytes>(line: Bytes) -> (String, [String])
        where Bytes: Sequence, Bytes.Element == UInt8 {

        var s = String(bytes: line, encoding: .utf8)!
        s = s.trimmingCharacters(in: ["\n"])
        let parts = s.components(separatedBy: " ")
        return (parts[0], Array(parts[1...]))
    }

    private static func isValidString(_ s: String) -> Bool {
        if s.count == 0 {
            return false
        }
        let bytes = s.data(using: .utf8)!
        for c in bytes {
            if c < 33 || c > 126 {
                return false
            }
        }
        return true
    }
}
