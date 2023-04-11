import Foundation
import NIOCore

public enum Armor {
    public static let header = "-----BEGIN AGE ENCRYPTED FILE-----"
    public static let footer = "-----END AGE ENCRYPTED FILE-----"
}

public enum ArmorError: Error {
    case writerAlreadyClosed
    case invalidHeader(String)
    case trailingDataAfterArmor
    case tooMuchTrailingWhitespace
    case base64DecodeError
}

// MARK: - Writer

extension Armor {
    public struct Writer {
        let dst: OutputStream
        private var started = false
        private var written = 0

        public init(dst: OutputStream) {
            self.dst = dst
        }

        public mutating func write(_ data: Data) throws -> Int {
            if !started {
                _ = try dst.write(Armor.header + "\n")
            }
            started = true
            written += try dst.write(
                data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            )
            written += try dst.write("\n")
            return written
        }

        public func close() throws {
            if dst.streamStatus == .closed {
                throw ArmorError.writerAlreadyClosed
            }
            _ = try dst.write(Armor.footer)
        }
    }
}

// MARK: - Reader

extension Armor {
    public struct Reader {
        private var src: ByteBuffer
        private var encoded = ""
        private var started = false
        private let maxWhitespace = 1024

        public init(src: InputStream) {
            // FIXME: Consuming the entire input is probably bad, but InputStream is too hard to work with.
            self.src = ByteBuffer(src)
        }

        public mutating func read(_ buffer: inout [UInt8]) throws -> Int {
            var read = 0
            if !started {
                guard let line = src.readString(until: "\n") else {
                    return -1
                }
                let header = line.trimmingCharacters(in: ["\n"])
                if header != Armor.header {
                    throw ArmorError.invalidHeader(header)
                }
                started = true
            }

            while src.readableBytes > 0 {
                guard let line = src.readString(until: "\n") else {
                    return -1
                }
                if line == Armor.footer {
                    break
                }
                encoded += line
                read += line.count
            }
            if src.readableBytes > 0 {
                let trailing = src.readString(length: min(src.readableBytes, maxWhitespace))
                guard let trailing, trailing.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw ArmorError.trailingDataAfterArmor
                }
                guard trailing.count < maxWhitespace else {
                    throw ArmorError.tooMuchTrailingWhitespace
                }
            }
            guard let enc = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else {
                throw ArmorError.base64DecodeError
            }

            buffer.append(contentsOf: enc)
            return read
        }
    }
}
