extension Shortcuts {
    static let git: [ShortcutGroup] = [
        ShortcutGroup(id: "Git", entries: [
            ShortcutEntry("gitchanges", "Changes Panel", [.menu("Git › Changes", "⌘0")]),
            ShortcutEntry("gitcommit", "Commit / Push", [.menu("Git › Commit…", "⌘K"), .menu("Git › Push", "⇧⌘K")]),
        ]),
    ]
}
