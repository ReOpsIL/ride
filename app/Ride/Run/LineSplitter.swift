import Foundation

struct LineSplitter {
    private var pending: [UInt8] = []

    init() {}

    mutating func take(_ bytes: [UInt8]) -> [String] {
        pending.append(contentsOf: bytes)
        return drain(flushing: false)
    }

    mutating func finish() -> [String] {
        drain(flushing: true)
    }

    mutating func flush() -> String? {
        let lines = finish()
        guard !lines.isEmpty else {
            return nil
        }
        return lines.count == 1 ? lines[0] : lines.joined(separator: "\n")
    }

    private mutating func drain(flushing: Bool) -> [String] {
        var lines: [String] = []
        var start = 0
        var index = 0
        while index < pending.count {
            let byte = pending[index]
            if byte == 0x0A {
                lines.append(Self.text(Array(pending[start..<index])))
                index += 1
                start = index
                continue
            }
            if byte == 0x0D {
                let next = index + 1
                if next == pending.count && !flushing {
                    break
                }
                lines.append(Self.text(Array(pending[start..<index])))
                index = next
                if index < pending.count, pending[index] == 0x0A {
                    index += 1
                }
                start = index
                continue
            }
            index += 1
        }
        if flushing, start < pending.count {
            lines.append(Self.text(Array(pending[start...])))
            start = pending.count
        }
        pending.removeFirst(start)
        return lines
    }

    private static func text(_ bytes: [UInt8]) -> String {
        var out = bytes
        if out.last == 0x0D {
            out.removeLast()
        }
        return String(decoding: out, as: UTF8.self)
    }
}
