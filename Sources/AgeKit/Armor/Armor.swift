import Foundation
import NIOCore

public enum Armor {
    private static let header = "-----BEGIN AGE ENCRYPTED FILE-----"
    private static let footer = "-----END AGE ENCRYPTED FILE-----"
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
            written += try dst.write(data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]))
            return try dst.write("\n")
        }

        public func close() throws {
            if dst.streamStatus == .closed {
                // TODO: throw already closed
            }
//            var footer = Armor.footer + "\n"
//            if written % Format.columnsPerLine == 0 {
//                footer = "\n" + Armor.footer
//            }
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

        init(src: InputStream) {
            // FIXME: Consuming the entire input is probably bad, but InputStream is too hard to work with.
            self.src = ByteBuffer(src)
        }

        public mutating func read(_ buffer: inout [UInt8]) -> Int {
            var read = 0
            if !started {
                debugPrint(#file, "Reading header line")
                guard let line = src.readString(until: "\n") else {
                    return -1
                }
                let header = line.trimmingCharacters(in: ["\n"])
                if header != Armor.header {
                    debugPrint(#file, "Header is incorrect: \(line)")
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
            guard let enc = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else {
                return -1
            }

            buffer.append(contentsOf: enc)
            return read
        }
    }
}
