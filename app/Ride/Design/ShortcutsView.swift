import SwiftUI

struct ShortcutEntry: Identifiable {
    let id: String
    let name: String
    let keys: String
}

enum Shortcuts {
    static let entries: [ShortcutEntry] = [
        ShortcutEntry(id: "open", name: "Open Folder", keys: "⌘O"),
        ShortcutEntry(id: "new", name: "New Buffer", keys: "⌘N"),
        ShortcutEntry(id: "save", name: "Save", keys: "⌘S"),
        ShortcutEntry(id: "close", name: "Close Editor", keys: "⌘W"),
        ShortcutEntry(id: "quick", name: "Open Quickly", keys: "⌘P"),
        ShortcutEntry(id: "find", name: "Find", keys: "⌘F"),
        ShortcutEntry(id: "next", name: "Find Next / Previous", keys: "⌘G · ⇧⌘G"),
        ShortcutEntry(id: "pfind", name: "Find in Project", keys: "⇧⌘F"),
        ShortcutEntry(id: "sym", name: "Go to Symbol in File", keys: "⌘R"),
        ShortcutEntry(id: "psym", name: "Go to Symbol in Project", keys: "⇧⌘R"),
        ShortcutEntry(id: "def", name: "Go to Definition", keys: "F12"),
        ShortcutEntry(id: "check", name: "Check", keys: "⌘B"),
        ShortcutEntry(id: "problems", name: "Show Problems", keys: "⇧⌘M"),
        ShortcutEntry(id: "format", name: "Format Document", keys: "⌃⇧I"),
        ShortcutEntry(id: "sidebar", name: "Toggle Sidebar", keys: "⌃⌘S"),
        ShortcutEntry(id: "cheat", name: "Cheat Sheet", keys: "⌃⇧Space"),
        ShortcutEntry(id: "help", name: "Keyboard Shortcuts", keys: "⌘/"),
    ]

    static var columns: [[ShortcutEntry]] {
        let half = (entries.count + 1) / 2
        return [Array(entries.prefix(half)), Array(entries.dropFirst(half))]
    }
}

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
