import Foundation

struct LineOffsets {
    private let lineStart: [Int]

    init(_ text: String) {
        var starts = [0]
        for (index, byte) in text.utf8.enumerated() where byte == 0x0A {
            starts.append(index + 1)
        }
        lineStart = starts
    }

    func byteOffset(line: UInt32, column: UInt32) -> UInt32 {
        let index = Int(line) - 1
        guard index >= 0, index < lineStart.count else {
            return 0
        }
        return UInt32(lineStart[index] + max(0, Int(column) - 1))
    }
}

enum ClangTidyParse {
    static func diagnostics(output: String, path: String, text: String) -> [StoredDiagnostic] {
        let offsets = LineOffsets(text)
        return output.split(separator: "\n").compactMap { parse(String($0), path: path, offsets: offsets) }
    }

    static func parse(_ line: String, path: String, offsets: LineOffsets) -> StoredDiagnostic? {
        guard line.hasPrefix(path + ":") else {
            return nil
        }
        let rest = line.dropFirst(path.count + 1)
        let parts = rest.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4,
              let lineNo = UInt32(parts[0].trimmingCharacters(in: .whitespaces)),
              let column = UInt32(parts[1].trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }
        let level: ProblemLevel
        switch parts[2].trimmingCharacters(in: .whitespaces) {
        case "error":
            level = .error
        case "warning":
            level = .warning
        default:
            return nil
        }
        var message = String(parts[3]).trimmingCharacters(in: .whitespaces)
        var code: String?
        if message.hasSuffix("]"), let open = message.lastIndex(of: "[") {
            code = String(message[message.index(after: open)..<message.index(before: message.endIndex)])
            message = String(message[..<open]).trimmingCharacters(in: .whitespaces)
        }
        let byte = offsets.byteOffset(line: lineNo, column: column)
        return StoredDiagnostic(
            path: path,
            byteStart: byte,
            byteEnd: byte + 1,
            line: lineNo,
            column: column,
            level: level,
            message: message,
            code: code,
            origin: .live
        )
    }
}
