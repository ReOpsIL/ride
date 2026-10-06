extension Shortcuts {
    static let fileEditView: [ShortcutGroup] = [
        ShortcutGroup(id: "File", entries: [
            ShortcutEntry("newproject", "New Project", [.menu("File › New Project…", "⇧⌘N")]),
            ShortcutEntry("new", "New File / New Buffer", [.menu("File › New File…", "⌘N"), .menu("File › New Buffer", "⌥⌘N")]),
            ShortcutEntry("open", "Open", [.menu("File › Open…", "⌘O")]),
            ShortcutEntry("save", "Save / Save As / Save All", [
                .menu("File › Save", "⌘S"), .menu("File › Save As…", "⇧⌘S"), .menu("File › Save All", "⌥⌘S"),
            ]),
            ShortcutEntry("close", "Close Editor / Close All", [.menu("File › Close Editor", "⌘W"), .menu("File › Close All", "⌥⌘W")]),
        ]),
        ShortcutGroup(id: "Edit", entries: [
            ShortcutEntry("dup", "Duplicate / Delete Line", [
                .menu("Edit › Duplicate Line", "⌘D", .editor), .menu("Edit › Delete Line", "⌘⌫", .editor),
            ]),
            ShortcutEntry("join", "Join Lines", [.menu("Edit › Join Lines", "⌃⇧J", .editor)]),
            ShortcutEntry("move", "Move Line Up / Down", [
                .menu("Edit › Move Line Up", "⌥⇧↑", .editor), .menu("Edit › Move Line Down", "⌥⇧↓", .editor),
            ]),
            ShortcutEntry("movestmt", "Move Statement Up / Down", [
                .menu("Edit › Move Statement Up", "⇧⌘↑", .editor), .menu("Edit › Move Statement Down", "⇧⌘↓", .editor),
            ]),
            ShortcutEntry("newline", "Start New Line / Before", [
                .menu("Edit › Start New Line", "⇧↩", .editor), .menu("Edit › Start New Line Before", "⌥⌘↩", .editor),
            ]),
            ShortcutEntry("case", "Toggle Case", [.menu("Edit › Toggle Case", "⇧⌘U", .editor)]),
            ShortcutEntry("selline", "Select Line / Word", [
                .menu("Edit › Select Line", "⇧⌘L", .editor), .menu("Edit › Select Word", "⌃W", .editor),
            ]),
            ShortcutEntry("sel", "Extend / Shrink Selection", [
                .menu("Edit › Extend Selection", "⌥↑", .editor), .menu("Edit › Shrink Selection", "⌥↓", .editor),
            ]),
            ShortcutEntry("copyref", "Copy Reference", [.menu("Edit › Copy Reference", "⌥⇧⌘C", .editor)]),
            ShortcutEntry("find", "Find / Find and Replace", [.menu("Edit › Find…", "⌘F"), .menu("Edit › Find and Replace…", "⌥⌘F")]),
            ShortcutEntry("next", "Find Next / Previous", [.menu("Edit › Find Next", "⌘G"), .menu("Edit › Find Previous", "⇧⌘G")]),
            ShortcutEntry("usesel", "Use Selection for Find", [.menu("Edit › Use Selection for Find", "⌥⌘E")]),
            ShortcutEntry("pfind", "Find / Replace in Project", [
                .menu("Edit › Find in Project…", "⇧⌘F"), .menu("Edit › Replace in Project…", "⇧⌘H"),
            ]),
        ]),
        ShortcutGroup(id: "View", entries: [
            ShortcutEntry("panels", "Sidebar / Debug / Run / Tests", [
                .menu("View › Project Sidebar", "⌘1"), .menu("Debug › Debug Panel", "⌘3"),
                .menu("View › Run Output", "⌘4"), .menu("View › Tests", "⌘5"),
            ]),
            ShortcutEntry("panels2", "Problems / Outline / AI Chat", [
                .menu("View › Problems", "⌘6"), .menu("View › Outline", "⌘7"), .menu("View › AI Chat", "⌘8"),
            ]),
            ShortcutEntry("terminal", "Terminal", [.menu("View › Terminal", "⌥F12")]),
            ShortcutEntry("preview", "Toggle Markdown Preview", [.menu("View › Toggle Markdown Preview", "⇧⌘V")]),
            ShortcutEntry("zoom", "Zoom In / Out / Actual Size", [
                .menu("View › Zoom In", "⌘="), .menu("View › Zoom Out", "⌘−"), .menu("View › Actual Size", "⌃⌘0"),
            ]),
            ShortcutEntry("split", "Toggle Split", [.menu("View › Toggle Split", "⌘\\")]),
        ]),
    ]
}
