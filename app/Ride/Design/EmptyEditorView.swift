import SwiftUI

struct EmptyEditorView: View {
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        ZStack {
            ts.editorBackground
            VStack(spacing: Tokens.Space.m) {
                Image(systemName: "doc.text")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(ts.ui.textTertiary)
                Text("No file open")
                    .font(Tokens.ui(14, weight: .medium))
                    .foregroundStyle(ts.ui.textSecondary)
                HStack(spacing: Tokens.Space.xs) {
                    Text("Select a file in the sidebar or press")
                    KeyCap(key: "⌘P")
                }
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                RustSrcHint()
                    .padding(.top, Tokens.Space.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RustSrcHint: View {
    @ObservedObject private var engine = RideEngineClient.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        if engine.statusKnown, !engine.rustSrcAvailable {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ts.ui.warning)
                Text("Standard library sources are missing. Run")
                    .foregroundStyle(ts.ui.textSecondary)
                Text(RustSrc.command)
                    .font(Tokens.mono(11))
                    .foregroundStyle(ts.ui.textPrimary)
                    .padding(.horizontal, Tokens.Space.s)
                    .padding(.vertical, 2)
                    .background(ts.ui.bgHover, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            }
            .font(Tokens.ui(11))
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.s)
            .background(ts.ui.bgRaised, in: RoundedRectangle(cornerRadius: Tokens.Radius.l))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.l)
                    .stroke(ts.ui.border, lineWidth: Tokens.Size.hairline)
            )
        }
    }
}

enum RustSrc {
    static let command = "rustup component add rust-src"
    static let hint = "rust-src missing: run `\(command)` to complete from std"
}
