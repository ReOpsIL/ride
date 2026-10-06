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
            GeometryReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            switch row.content {
                            case .hunk(let hunk): GitHunkHeader(hunk: hunk, width: proxy.size.width)
                            case .line(let line): GitDiffLineRow(line: line, width: proxy.size.width)
                            }
                        }
                    }
                    .padding(.vertical, Tokens.Space.xs)
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
                    .textSelection(.enabled)
                }
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
    let width: CGFloat

    var body: some View {
        Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@ \(hunk.header)")
            .font(Tokens.mono(11))
            .foregroundStyle(ts.ui.info)
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xxs)
            .frame(minWidth: width, alignment: .leading)
            .background(ts.ui.info.opacity(0.08))
    }
}

struct GitDiffLineRow: View {
    @ObservedObject private var ts = ThemeStore.shared
    let line: GitDiffLine
    let width: CGFloat

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
        .frame(minWidth: width, minHeight: 16, alignment: .leading)
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
