import AppKit

enum DemoScene {
    static func run(_ name: String, state: AppState) {
        prepare(state)
        let handled = base(name, state: state)
            || popups(name, state: state)
            || docs(name, state: state)
            || running(name, state: state)
            || languages(name, state: state)
        if !handled {
            DemoLaunch.ready()
        }
    }

    private static func prepare(_ state: AppState) {
        state.prefs.autoSave = false
        state.persistLayout = false
        DemoLaunch.activate()
        guard let theme = DemoLaunch.theme else {
            return
        }
        state.prefs.theme = theme
        state.applyTheme()
    }

    private static func base(_ name: String, state: AppState) -> Bool {
        switch name {
        case "empty":
            DemoLaunch.ready()
        case "editor":
            editor(state)
            ready(after: 1.2)
        case "file":
            editor(state, file: DemoLaunch.file ?? "src/main.rs", line: 1)
            if DemoLaunch.scroll {
                DemoLaunch.after(1.5) { autoScroll(step: 0) }
            }
            ready(after: 1.2)
        case "selftest":
            editor(state, file: DemoLaunch.file ?? defaultEditorFile(state))
            DemoLaunch.after(1.5) {
                DemoSelfTest.start(state: state, report: DemoLaunch.report ?? "/tmp/ride-selftest.txt")
            }
        case "outline":
            state.prefs.outlinePanel = true
            editor(state)
            ready(after: 1.2)
        case "light":
            state.prefs.theme = "light"
            state.applyTheme()
            editor(state)
            ready(after: 1.2)
        case "preview":
            editor(state, file: "README.md", line: 1)
            DemoLaunch.after(0.8) {
                state.showPreview = true
                state.refreshPreview()
            }
            ready(after: 2.0)
        default:
            return false
        }
        return true
    }

    static func ready(after seconds: Double) {
        DemoLaunch.after(seconds) { DemoLaunch.ready() }
    }

    static func ready(when condition: @escaping () -> Bool, timeout: Double = 300) {
        poll(condition, deadline: Date().addingTimeInterval(timeout))
    }

    private static func poll(_ condition: @escaping () -> Bool, deadline: Date) {
        DemoLaunch.after(0.5) {
            guard !condition(), Date() < deadline else {
                DemoLaunch.ready()
                return
            }
            poll(condition, deadline: deadline)
        }
    }

    private static func autoScroll(step: Int) {
        guard step < 40 else {
            return
        }
        EditorPanes.shared.focused?.jump(toLine: 1 + step * 400)
        DemoLaunch.after(0.1) { autoScroll(step: step + 1) }
    }

    private static func defaultEditorFile(_ state: AppState) -> String {
        guard let root = state.workspaceRoot else {
            return "src/main.rs"
        }
        let candidates = ["src/main.rs", "src/shapes.cpp", "src/main.cpp"]
        return candidates.first { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) } ?? "src/main.rs"
    }

    static func editor(_ state: AppState, file: String = "src/main.rs", line: Int = 9) {
        guard let root = state.workspaceRoot else {
            return
        }
        state.openFile(root.appendingPathComponent(file))
        DemoLaunch.after(0.6) {
            EditorPanes.shared.focused?.jump(toLine: line)
        }
    }

    static func open(_ state: AppState, file: String) -> URL? {
        guard let root = state.workspaceRoot else {
            return nil
        }
        let url = root.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        state.openFile(url)
        return url
    }
}
