import Foundation

public class Format {
    public struct Header {
        var recipients: [Stanza] = []
        var mac = Data()
    }

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
    }

    struct UnexpectedNewLineError: Error {}
    struct Base64DecodeError: Error {}

    public static func decodeString(_ s: String) throws -> Data {
        if #available(macOS 13.0, *) {
            if s.contains(["\n", "\r"]) {
                throw UnexpectedNewLineError()
            }
        } else {
            if s.contains("\n") || s.contains("\r") {
                throw UnexpectedNewLineError()
            }
        }
        if let b64 = Data(base64Encoded: s) {
            return b64
        }
        throw Base64DecodeError()
    }

    static let columsPerLine = 64
    static var bytesPerLine: Int { columsPerLine / 4 * 3 }

    enum StanzaError: Error {
        case LineError, MalformedOpeningLine, MalformedStanza, MalformedBodyLineSize
    }

    static let intro = "age-encryption.org/v1\n".data(using: .utf8)!

    static let stanzaPrefix = "->".data(using: .utf8)!
    static let footerPrefix = "---".data(using: .utf8)!

    public static func readStanza(input: InputStream) throws -> Stanza {
        var s = Stanza()

        guard let line = try input.readLine() else {
            throw StanzaError.LineError
        }
        if !line.starts(with: stanzaPrefix) {
            throw StanzaError.MalformedOpeningLine
        }
        let (prefix, args) = splitArgs(line: line)
        if prefix != String(data: stanzaPrefix, encoding: .utf8)! || args.count < 1 {
            throw StanzaError.MalformedStanza
        }
        for a in args {
            if !isValidString(a) {
                throw StanzaError.MalformedStanza
            }
        }
        s.type = args[0]
        s.args = Array(args[1...])

        while true {
            guard let line = try input.readLine() else {
                throw StanzaError.LineError
            }

            var lineStr = String(data: line, encoding: .utf8)!
            lineStr = lineStr.trimmingCharacters(in: ["\n"])
            let b: Data
            do {
                b = try decodeString(lineStr)

                if b.count > bytesPerLine {
                    throw StanzaError.MalformedBodyLineSize
                }
                s.body.append(b)
                if b.count < bytesPerLine {
                    return s
                }
            } catch {
                // TODO: The Go implementation checks the value for the footerPrefix and stanzaPrefix
            }
        }
    }

    enum ParseError: Error {
        case IntroRead, UnexpectedIntro, ReadHeader, MalformedClosingLine
    }

    public static func parse(input: InputStream) throws -> (Header, InputStream) {
        var h = Header()

        guard let line = try input.readLine() else {
            throw ParseError.IntroRead
        }
        if line != Format.intro {
            throw ParseError.UnexpectedIntro
        }

        let bufSize = 4096 // equal to Go's bufio.NewReader defaultBufSize
        var buffer = Data(capacity: bufSize)
        while input.read(&buffer, maxLength: bufSize) > 0 {
            if buffer[...footerPrefix.count] == footerPrefix {
                guard let line = buffer.readLine() else {
                    throw ParseError.ReadHeader
                }
                let (prefix, args) = splitArgs(line: line)
                if prefix != String(data: footerPrefix, encoding: .utf8)! || args.count != 1 {
                    throw ParseError.MalformedClosingLine
                }
                h.mac = try decodeString(args[0])
                if h.mac.count != 32 {
                    throw ParseError.MalformedClosingLine
                }
                break
            }

            let s = try readStanza(input: input)
            h.recipients.append(s)
        }

        return (h, input)
    }

    private static func splitArgs(line: Data) -> (String, [String]) {
        var s = String(data: line, encoding: .utf8)!
        s = s.trimmingCharacters(in: ["\n"])
        let parts = s.components(separatedBy: "\n")
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


