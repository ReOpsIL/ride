import SwiftUI

struct ThemeSwatchPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Tokens.Space.l) {
            ThemeSwatch(name: "dark", title: "Dark", selected: selection == "dark") {
                selection = "dark"
            }
            ThemeSwatch(name: "light", title: "Light", selected: selection == "light") {
                selection = "light"
            }
        }
    }
}

private struct ThemeSwatch: View {
    @ObservedObject private var ts = ThemeStore.shared
    let name: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let theme = Theme.load(name: name)
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
                        .fill(Color(theme.editor.background))
                    VStack(alignment: .leading, spacing: 3) {
                        line(theme.keyword, theme.type, theme.punctuation)
                        line(theme.function, theme.string, theme.punctuation)
                        line(theme.comment, theme.comment, theme.comment)
                    }
                    .padding(Tokens.Space.m)
                }
                .frame(width: 150, height: 68)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
                        .stroke(Color(theme.chrome.border), lineWidth: Tokens.Size.hairline)
                )
                HStack(spacing: Tokens.Space.xs) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? ts.ui.accent : ts.ui.textTertiary)
                    Text(title)
                        .foregroundStyle(ts.ui.textPrimary)
                }
                .font(Tokens.ui(12, weight: selected ? .semibold : .regular))
            }
            .padding(Tokens.Space.s)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.l, style: .continuous)
                    .stroke(selected ? ts.ui.accent : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func line(_ a: NSColor, _ b: NSColor, _ c: NSColor) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(Color(a)).frame(width: 26, height: 5)
            Capsule().fill(Color(b)).frame(width: 40, height: 5)
            Capsule().fill(Color(c)).frame(width: 14, height: 5)
        }
    }
}
