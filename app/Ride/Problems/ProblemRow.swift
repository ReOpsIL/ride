import SwiftUI

struct ProblemRow: View {
    let diag: StoredDiagnostic
    let location: String
    let selected: Bool
    let fix: (StoredFix) -> Void
    let action: () -> Void
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        if diag.fixes.isEmpty {
            row
        } else {
            row.contextMenu {
                ForEach(Array(diag.fixes.enumerated()), id: \.offset) { _, entry in
                    Button(entry.title) { fix(entry) }
                }
            }
        }
    }

    private var row: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: diag.level == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(diag.level == .error ? ts.ui.error : ts.ui.warning)
                .frame(width: 14)
            Text(diag.message)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Text(location)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(1)
            if diag.origin == .build {
                tag("build", tint: ts.ui.textTertiary)
            }
            if diag.origin == .live {
                tag("live", tint: ts.ui.accent)
            }
            if let code = diag.code {
                if let link = DiagnosticDocLink.url(for: code) {
                    Button(action: { NSWorkspace.shared.open(link) }) {
                        tag(code, tint: ts.ui.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Open documentation for \(code)")
                } else {
                    tag(code, tint: ts.ui.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.sidebarRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? ts.ui.bgSelection : (hovering ? ts.ui.bgHover : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }

    private func tag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Tokens.mono(10))
            .foregroundStyle(tint)
            .padding(.horizontal, Tokens.Space.xs)
            .background(ts.ui.bgHover, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
    }
}
