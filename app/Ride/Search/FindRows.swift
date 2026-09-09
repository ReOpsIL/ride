import SwiftUI

struct FindGroupHeader: View {
    @ObservedObject private var ts = ThemeStore.shared
    let file: URL
    let count: Int
    let label: String

    var body: some View {
        let spec = FileIcon.spec(name: file.lastPathComponent, isDirectory: false, chrome: ts.chrome)
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: spec.symbol)
                .font(.system(size: 11))
                .foregroundStyle(Color(spec.color))
            Text(label)
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(count)")
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .padding(.horizontal, Tokens.Space.s)
                .background(ts.ui.bgHover, in: Capsule())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.xl)
        .frame(height: Tokens.Size.pickerRow)
    }
}

struct FindMatchRow: View {
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false
    let match: ProjectFindMatch
    let query: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Text("\(match.line)")
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(width: 44, alignment: .trailing)
            HighlightedText.marks(match.preview, query: query, base: ts.ui.textPrimary, mark: ts.ui.accent.opacity(0.35), font: Tokens.mono(12))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.pickerRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            selected ? ts.ui.accent.opacity(0.28) : (hovering ? ts.ui.bgHover : Color.clear),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
        )
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }
}
