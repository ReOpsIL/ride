import SwiftUI

struct ShortcutEntry: Identifiable {
    let id: String
    let name: String
    let keys: String
}

enum Shortcuts {
    static let entries: [ShortcutEntry] = [
        ShortcutEntry(id: "open", name: "Open…", keys: "⌘O"),
        ShortcutEntry(id: "new", name: "New File / New Buffer", keys: "⌘N · ⌥⌘N"),
        ShortcutEntry(id: "save", name: "Save / Save As / Save All", keys: "⌘S · ⇧⌘S · ⌥⌘S"),
        ShortcutEntry(id: "close", name: "Close Editor / Close All", keys: "⌘W · ⌥⌘W"),
        ShortcutEntry(id: "dup", name: "Duplicate / Delete Line", keys: "⌘D · ⌘⌫"),
        ShortcutEntry(id: "move", name: "Move Line Up / Down", keys: "⌥⇧↑ · ⌥⇧↓"),
        ShortcutEntry(id: "join", name: "Join Lines", keys: "⌃⇧J"),
        ShortcutEntry(id: "newline", name: "Start New Line / Before", keys: "⇧↩ · ⌥⌘↩"),
        ShortcutEntry(id: "sel", name: "Extend / Shrink Selection", keys: "⌥↑ · ⌥↓"),
        ShortcutEntry(id: "selline", name: "Select Line / Word", keys: "⇧⌘L · ⌃W"),
        ShortcutEntry(id: "case", name: "Toggle Case", keys: "⇧⌘U"),
        ShortcutEntry(id: "comment", name: "Comment Line / Block", keys: "⌘/ · ⌥⌘/"),
        ShortcutEntry(id: "indent", name: "Indent / Unindent Selection", keys: "⇥ · ⇧⇥"),
        ShortcutEntry(id: "autoindent", name: "Auto-Indent Lines", keys: "⌃⌥I"),
        ShortcutEntry(id: "format", name: "Reformat Document", keys: "⌃⇧I"),
        ShortcutEntry(id: "surround", name: "Surround With", keys: "⌥⌘T"),
        ShortcutEntry(id: "fold", name: "Fold / Unfold", keys: "⌥⌘← · ⌥⌘→"),
        ShortcutEntry(id: "foldall", name: "Fold All / Unfold All", keys: "⇧⌥⌘← · ⇧⌥⌘→"),
        ShortcutEntry(id: "find", name: "Find / Find and Replace", keys: "⌘F · ⌥⌘F"),
        ShortcutEntry(id: "next", name: "Find Next / Previous", keys: "⌘G · ⇧⌘G"),
        ShortcutEntry(id: "pfind", name: "Find in Project", keys: "⇧⌘F"),
        ShortcutEntry(id: "quick", name: "Open Quickly / Recent Files", keys: "⌘P · ⌘E"),
        ShortcutEntry(id: "back", name: "Back / Forward", keys: "⌘[ · ⌘]"),
        ShortcutEntry(id: "lastedit", name: "Last Edit Location", keys: "⇧⌘⌫"),
        ShortcutEntry(id: "line", name: "Go to Line", keys: "⌘L"),
        ShortcutEntry(id: "sym", name: "Go to Symbol in File / Project", keys: "⌘R · ⇧⌘R"),
        ShortcutEntry(id: "def", name: "Go to Definition", keys: "F12"),
        ShortcutEntry(id: "header", name: "Switch Header / Source", keys: "⌃⌥↑"),
        ShortcutEntry(id: "problem", name: "Next / Previous Problem", keys: "F2 · ⇧F2"),
        ShortcutEntry(id: "method", name: "Next / Previous Method", keys: "⌃↓ · ⌃↑"),
        ShortcutEntry(id: "brace", name: "Matching Brace", keys: "⌃M"),
        ShortcutEntry(id: "complete", name: "Trigger Completion", keys: "⌃Space"),
        ShortcutEntry(id: "cheat", name: "Cheat Sheet", keys: "⌃⇧Space"),
        ShortcutEntry(id: "doc", name: "Quick Documentation / Signature", keys: "⌃J · ⇧⌘Space"),
        ShortcutEntry(id: "peek", name: "Quick Definition", keys: "⌥Space"),
        ShortcutEntry(id: "check", name: "Check", keys: "⌘B"),
        ShortcutEntry(id: "panels", name: "Sidebar / Problems / Outline", keys: "⌘1 · ⌘6 · ⌘7"),
        ShortcutEntry(id: "zoom", name: "Zoom In / Out / Reset", keys: "⌘= · ⌘− · ⌃⌘0"),
        ShortcutEntry(id: "help", name: "Keyboard Shortcuts", keys: "⌘?"),
    ]

    static var columns: [[ShortcutEntry]] {
        let third = (entries.count + 2) / 3
        return stride(from: 0, to: entries.count, by: third).map { Array(entries[$0..<min($0 + third, entries.count)]) }
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
