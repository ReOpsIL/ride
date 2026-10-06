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
                    Grid(alignment: .leading, horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.xs) {
                        ForEach(column) { group in
                            section(group)
                        }
                    }
                }
            }
        }
        .padding(Tokens.Space.xxl)
        .fixedSize()
        .background(ts.ui.bgRaised)
    }

    static var columns: [[ShortcutGroup]] {
        ShortcutColumns.balance(Shortcuts.groups, into: 3)
    }

    @ViewBuilder
    private func section(_ group: ShortcutGroup) -> some View {
        GridRow {
            Text(group.id)
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .padding(.top, Tokens.Space.m)
                .gridCellColumns(2)
        }
        ForEach(group.entries) { entry in
            GridRow {
                Text(entry.name)
                    .font(Tokens.ui(12))
                    .foregroundStyle(ts.ui.textPrimary)
                keys(entry)
            }
            .frame(height: 20)
            .help(entry.note ?? "")
        }
    }

    private func keys(_ entry: ShortcutEntry) -> some View {
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
        .fixedSize()
    }
}
