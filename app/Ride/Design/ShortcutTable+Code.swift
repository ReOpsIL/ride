extension Shortcuts {
    static let navigateCode: [ShortcutGroup] = [
        ShortcutGroup(id: "Navigate", entries: [
            ShortcutEntry("quick", "Open Quickly / Recent Files", [.menu("Navigate › Open Quickly…", "⌘P"), .menu("Navigate › Recent Files…", "⌘E")]),
            ShortcutEntry("back", "Back / Forward", [.menu("Navigate › Back", "⌘["), .menu("Navigate › Forward", "⌘]")]),
            ShortcutEntry("lastedit", "Last Edit Location", [.menu("Navigate › Last Edit Location", "⇧⌘⌫")]),
            ShortcutEntry("line", "Go to Line", [.menu("Navigate › Go to Line…", "⌘L")]),
            ShortcutEntry("sym", "Go to Symbol in File / Project", [
                .menu("Navigate › Go to Symbol in File…", "⌥⌘O"), .menu("Navigate › Go to Symbol in Project…", "⌥⇧⌘O"),
            ]),
            ShortcutEntry("def", "Go to Definition", [.menu("Navigate › Go to Definition", "F12", .editor)]),
            ShortcutEntry("header", "Switch Header / Source", [.menu("Navigate › Switch Header / Source", "F10")]),
            ShortcutEntry("usages", "Find Usages", [.menu("Navigate › Find Usages", "⌥F7", .editor)]),
            ShortcutEntry("hier", "Call / Type Hierarchy", [
                .menu("Navigate › Call Hierarchy", "⌃⌥H", .editor), .menu("Navigate › Type Hierarchy", "⌃H", .editor),
            ]),
            ShortcutEntry("rename", "Rename / Safe Delete", [
                .menu("Navigate › Rename…", "⇧F6", .editor), .menu("Navigate › Safe Delete…", "⌥⌘⌫", .editor),
            ]),
            ShortcutEntry("problem", "Next / Previous Problem", [.menu("Navigate › Next Problem", "F2"), .menu("Navigate › Previous Problem", "⇧F2")]),
            ShortcutEntry("method", "Next / Previous Method", [
                .menu("Navigate › Next Method", "⌃↓", .editor), .menu("Navigate › Previous Method", "⌃↑", .editor),
            ], note: "macOS gives ⌃↑ / ⌃↓ to Mission Control and App Exposé unless they are turned off in System Settings › Keyboard › Keyboard Shortcuts"),
            ShortcutEntry("brace", "Matching Brace", [.menu("Navigate › Matching Brace", "⌃M", .editor)]),
        ]),
        ShortcutGroup(id: "Code", entries: [
            ShortcutEntry("comment", "Comment Line / Block", [.menu("Code › Comment Line", "⌘/", .editor), .menu("Code › Comment Block", "⌥⌘/", .editor)]),
            ShortcutEntry("indent", "Indent / Unindent Selection", [.editorKey("⇥"), .editorKey("⇧⇥")]),
            ShortcutEntry("autoindent", "Auto-Indent Lines", [.menu("Code › Auto-Indent Lines", "⌃⌥I", .editor)]),
            ShortcutEntry("format", "Reformat Document / Selection", [
                .menu("Code › Reformat Document", "⌃⇧I", .editor), .menu("Code › Reformat Selection", "⌥⌘L", .editor),
            ]),
            ShortcutEntry("complete", "Complete Statement", [.menu("Code › Complete Statement", "⇧⌘↩", .editor)]),
            ShortcutEntry("generate", "Generate", [.menu("Code › Generate…", "⌃⌘G", .editor)]),
            ShortcutEntry("extract", "Extract Variable / Introduce Constant", [
                .menu("Code › Extract Variable", "⌥⌘V", .editor), .menu("Code › Introduce Constant", "⌥⌘C", .editor),
            ]),
            ShortcutEntry("inline", "Inline Variable", [.menu("Code › Inline Variable", "⌃⌥N", .editor)]),
            ShortcutEntry("intentions", "Show Intention Actions", [.menu("Code › Show Intention Actions", "⌥↩", .editor)]),
            ShortcutEntry("askai", "Ask AI from Comment", [.menu("Code › Ask AI from Comment…", "⌃?", .editor)]),
            ShortcutEntry("surround", "Surround With", [.menu("Code › Surround With…", "⌥⌘T", .editor)]),
            ShortcutEntry("fold", "Fold / Unfold", [.menu("Code › Fold", "⌥⌘←", .editor), .menu("Code › Unfold", "⌥⌘→", .editor)]),
            ShortcutEntry("foldall", "Fold All / Unfold All", [.menu("Code › Fold All", "⌥⇧⌘←", .editor), .menu("Code › Unfold All", "⌥⇧⌘→", .editor)]),
            ShortcutEntry("trigger", "Trigger Completion", [.menu("Code › Trigger Completion", "⌃Space", .editor), .editorKey("⌥esc")],
                          note: "macOS uses ⌃Space for Select Previous Input Source; ⌥esc always works"),
            ShortcutEntry("cheat", "Cheat Sheet", [.menu("Code › Cheat Sheet", "⌃⇧Space", .editor)]),
            ShortcutEntry("doc", "Quick Documentation", [.menu("Code › Quick Documentation", "⌃J", .editor), .menu("Code › Quick Documentation", "F1", .editor)]),
            ShortcutEntry("peek", "Quick Definition", [.menu("Code › Quick Definition", "⌥Space", .editor)]),
            ShortcutEntry("typeinfo", "Type Info", [.menu("Code › Type Info", "⌃⇧P", .editor)]),
            ShortcutEntry("extdoc", "External Documentation", [.menu("Code › External Documentation", "⇧F1", .editor)]),
            ShortcutEntry("signature", "Signature Help", [.menu("Code › Signature Help", "⇧⌘Space", .editor)]),
        ]),
        ShortcutGroup(id: "Build", entries: [
            ShortcutEntry("check", "Check / Check Project", [.menu("Build › Check", "⌥⌘B"), .menu("Build › Check Project", "⌥⇧⌘B")]),
        ]),
    ]
}
