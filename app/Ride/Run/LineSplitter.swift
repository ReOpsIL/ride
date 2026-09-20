import Foundation

struct LineSplitter {
    private var pending: [UInt8] = []

    init() {}

    mutating func take(_ bytes: [UInt8]) -> [String] {
        pending.append(contentsOf: bytes)
        guard let last = pending.lastIndex(of: 0x0A) else {
            return []
        }
        let complete = Array(pending[..<last])
        pending.removeSubrange(...last)
        return Self.split(complete)
    }

    mutating func flush() -> String? {
        guard !pending.isEmpty else {
            return nil
        }
        let rest = pending
        pending = []
        return Self.line(rest)
    }

    private static func split(_ bytes: [UInt8]) -> [String] {
        var out: [String] = []
        var current: [UInt8] = []
        for b in bytes {
            if b == 0x0A {
                if current.last == 0x0D {
                    current.removeLast()
                }
                out.append(line(current))
                current = []
            } else if b == 0x0D {
                out.append(line(current))
                current = []
            } else {
                current.append(b)
            }
        }
        if !current.isEmpty {
            out.append(line(current))
        }
        return out
    }

    private static func line(_ bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }
}
