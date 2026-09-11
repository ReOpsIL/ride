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
        bytes.split(separator: 0x0A, omittingEmptySubsequences: false).map { line(Array($0)) }
    }

    private static func line(_ bytes: [UInt8]) -> String {
        var out = bytes
        if out.last == 0x0D {
            out.removeLast()
        }
        return String(decoding: out, as: UTF8.self)
    }
}
