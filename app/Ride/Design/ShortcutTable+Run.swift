extension Shortcuts {
    static let runDebug: [ShortcutGroup] = [
        ShortcutGroup(id: "Run", entries: [
            ShortcutEntry("run", "Build / Run / Run Tests", [.menu("Run › Build", "⌘B"), .menu("Run › Run", "⌘R"), .menu("Run › Run Tests", "⇧⌘R")]),
            ShortcutEntry("runfile", "Run File / Recompile File", [.menu("Run › Run File", "⌃⇧R"), .menu("Run › Recompile File", "⇧⌘F9")]),
            ShortcutEntry("stop", "Stop", [.menu("Run › Stop", "⌘.")]),
        ]),
        ShortcutGroup(id: "Debug", entries: [
            ShortcutEntry("debug", "Debug / Continue", [.menu("Debug › Debug", "⌃⌘R"), .menu("Debug › Continue", "⌥⌘R")]),
            ShortcutEntry("step", "Step Over / Into / Out", [
                .menu("Debug › Step Over", "F8"), .menu("Debug › Step Into", "F7"), .menu("Debug › Step Out", "⇧F8"),
            ]),
            ShortcutEntry("debugstop", "Stop Debugging", [.menu("Debug › Stop", "⌘F2")]),
            ShortcutEntry("breakpoint", "Toggle Breakpoint", [.menu("Debug › Toggle Breakpoint", "⌘F8", .editor)]),
            ShortcutEntry("evaluate", "Evaluate Expression", [.menu("Debug › Evaluate Expression…", "⌥F8")]),
        ]),
        ShortcutGroup(id: "Help", entries: [
            ShortcutEntry("help", "Keyboard Shortcuts", [.menu("Help › Keyboard Shortcuts", "⌘?")]),
        ]),
    ]
}
