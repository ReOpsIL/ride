import SwiftUI

struct ShortcutsView: View {
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Keyboard Shortcuts")
                .font(Tokens.ui(15, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                ForEach(Array(Shortcuts.columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: Tokens.Space.s) {
                        ForEach(column) { entry in
                            row(entry)
                        }
                    }
                }
            }
        }
        .padding(Tokens.Space.xxl)
        .background(ts.ui.bgRaised)
    }

    private func row(_ entry: ShortcutEntry) -> some View {
        HStack(spacing: Tokens.Space.l) {
            Text(entry.name)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .frame(width: 170, alignment: .leading)
            HStack(spacing: Tokens.Space.xs) {
                ForEach(entry.keys.split(separator: "·").map { $0.trimmingCharacters(in: .whitespaces) }, id: \.self) { key in
                    KeyCap(key: key, size: 11)
                }
            }
        }
        .frame(height: 22)
    }
}
