import SwiftUI

struct ShortcutsView: View {
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Keyboard Shortcuts")
                .font(Tokens.ui(15, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                ForEach(Array(Self.columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: Tokens.Space.s) {
                        ForEach(column) { group in
                            section(group)
                        }
                    }
                }
            }
        }
        .padding(Tokens.Space.xxl)
        .background(ts.ui.bgRaised)
    }

    static var columns: [[ShortcutGroup]] {
        let total = Shortcuts.groups.reduce(0) { $0 + $1.entries.count + 1 }
        let target = (total + 2) / 3
        var columns: [[ShortcutGroup]] = [[]]
        var filled = 0
        for group in Shortcuts.groups {
            if filled >= target, columns.count < 3 {
                columns.append([])
                filled = 0
            }
            columns[columns.count - 1].append(group)
            filled += group.entries.count + 1
        }
        return columns
    }

    private func section(_ group: ShortcutGroup) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(group.id)
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .padding(.top, Tokens.Space.s)
            ForEach(group.entries) { entry in
                row(entry)
            }
        }
    }

    private func row(_ entry: ShortcutEntry) -> some View {
        HStack(spacing: Tokens.Space.l) {
            Text(entry.name)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .frame(width: 200, alignment: .leading)
            HStack(spacing: Tokens.Space.xs) {
                ForEach(Array(entry.bindings.enumerated()), id: \.offset) { _, binding in
                    KeyCap(key: binding.keys, size: 11)
                }
                if entry.note != nil {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(ts.ui.textTertiary)
                }
            }
        }
        .frame(height: 20)
        .help(entry.note ?? "")
    }
}
