import AppKit

extension NSAttributedString.Key {
    static let gitDiffTint = NSAttributedString.Key("RideGitDiffTint")
}

struct GitDiffNumbers {
    let old: UInt32?
    let new: UInt32?
}

struct GitDiffDocument {
    let text: NSAttributedString
    let numbers: [GitDiffNumbers]
    let lineStarts: [Int]
    let digits: Int

    func line(atCharacter index: Int) -> Int {
        var low = 0
        var high = lineStarts.count
        while low < high {
            let mid = (low + high) / 2
            if lineStarts[mid] <= index {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return max(0, low - 1)
    }
}

struct GitDiffDocumentBuilder {
    let theme: Theme
    let font: NSFont
    private let out = NSMutableAttributedString()
    private var numbers: [GitDiffNumbers] = []
    private var lineStarts: [Int] = []

    init(theme: Theme, font: NSFont) {
        self.theme = theme
        self.font = font
    }

    static func build(_ diff: GitFileDiff, theme: Theme, font: NSFont) -> GitDiffDocument {
        var builder = GitDiffDocumentBuilder(theme: theme, font: font)
        for hunk in diff.hunks {
            builder.append(header: hunk)
            for line in hunk.lines {
                builder.append(line: line)
            }
        }
        return builder.finish()
    }

    private mutating func append(header hunk: GitHunk) {
        let title = "@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@ \(hunk.header)"
        let piece = NSMutableAttributedString(string: title, attributes: base(theme.chrome.info))
        appendLine(piece, numbers: GitDiffNumbers(old: nil, new: nil), tint: theme.chrome.info.withAlphaComponent(0.08))
    }

    private mutating func append(line: GitDiffLine) {
        let tint = self.tint(line.kind)
        let piece = NSMutableAttributedString(string: sign(line.kind) + " ", attributes: base(tint ?? theme.chrome.textTertiary))
        let body = NSMutableAttributedString(string: line.text, attributes: base(theme.chrome.textPrimary))
        let full = NSRange(location: 0, length: body.length)
        let map = Utf16Map(line.text)
        for span in line.spans {
            let range = NSIntersectionRange(map.nsRange(startByte: span.startByte, endByte: span.endByte), full)
            if range.length > 0 {
                body.addAttribute(.foregroundColor, value: theme.color(span.capture), range: range)
            }
        }
        piece.append(body)
        appendLine(piece, numbers: GitDiffNumbers(old: line.oldLine, new: line.newLine), tint: tint?.withAlphaComponent(0.14))
    }

    private mutating func appendLine(_ piece: NSMutableAttributedString, numbers: GitDiffNumbers, tint: NSColor?) {
        if let tint {
            piece.addAttribute(.gitDiffTint, value: tint, range: NSRange(location: 0, length: piece.length))
        }
        if !lineStarts.isEmpty {
            out.append(NSAttributedString(string: "\n", attributes: base(theme.chrome.textPrimary)))
        }
        let start = out.length
        out.append(piece)
        lineStarts.append(start)
        self.numbers.append(numbers)
    }

    private func finish() -> GitDiffDocument {
        let widest = numbers.map { max($0.old ?? 0, $0.new ?? 0) }.max() ?? 0
        return GitDiffDocument(text: out, numbers: numbers, lineStarts: lineStarts, digits: max(3, String(widest).count))
    }

    private func base(_ color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color]
    }

    private func sign(_ kind: GitLineKind) -> String {
        switch kind {
        case .added: return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }

    private func tint(_ kind: GitLineKind) -> NSColor? {
        switch kind {
        case .added: return theme.chrome.success
        case .removed: return theme.chrome.error
        case .context: return nil
        }
    }
}
