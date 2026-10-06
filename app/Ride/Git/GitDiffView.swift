import SwiftUI

struct GitDiffView: View {
    @ObservedObject private var ts = ThemeStore.shared
    let diff: GitFileDiff?
    let rows: [GitDiffRow]
    let error: String?
    let hasSelection: Bool

    var body: some View {
        if let error {
            placeholder(error)
        } else if let diff, diff.binary {
            placeholder("Binary file \(diff.path)")
        } else if let diff, !diff.hunks.isEmpty {
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        switch row.content {
                        case .hunk(let hunk): GitHunkHeader(hunk: hunk)
                        case .line(let line): GitDiffLineRow(line: line)
                        }
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
                .textSelection(.enabled)
            }
            .background(ts.editorBackground)
        } else {
            placeholder(hasSelection && diff != nil ? "No differences" : "Select a file to see its diff")
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Tokens.Space.l)
    }
}

struct GitHunkHeader: View {
    @ObservedObject private var ts = ThemeStore.shared
    let hunk: GitHunk

    var body: some View {
        Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@ \(hunk.header)")
            .font(Tokens.mono(11))
            .foregroundStyle(ts.ui.info)
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ts.ui.info.opacity(0.08))
    }
}

struct GitDiffLineRow: View {
    @ObservedObject private var ts = ThemeStore.shared
    let line: GitDiffLine

    var body: some View {
        HStack(spacing: 0) {
            number(line.oldLine)
            number(line.newLine)
            Text(sign)
                .frame(width: 14)
                .foregroundStyle(tint ?? ts.ui.textTertiary)
            Text(line.text.isEmpty ? " " : line.text)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(ts.ui.textPrimary)
            Spacer(minLength: Tokens.Space.l)
        }
        .font(Tokens.mono(11))
        .frame(minHeight: 16)
        .background(tint?.opacity(0.14) ?? .clear)
    }

    private var sign: String {
        switch line.kind {
        case .added: return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }

    private var tint: Color? {
        switch line.kind {
        case .added: return ts.ui.success
        case .removed: return ts.ui.error
        case .context: return nil
        }
    }

    private func number(_ value: UInt32?) -> some View {
        Text(value.map { String($0) } ?? "")
            .foregroundStyle(ts.ui.textTertiary)
            .frame(width: 40, alignment: .trailing)
            .padding(.trailing, Tokens.Space.xs)
    }
}
