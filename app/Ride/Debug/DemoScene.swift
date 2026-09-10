import AppKit

enum DemoScene {
    static func run(_ name: String, state: AppState) {
        state.prefs.autoSave = false
        state.persistLayout = false
        if let theme = DemoLaunch.theme {
            state.prefs.theme = theme
            state.applyTheme()
        }
        switch name {
        case "empty":
            break
        case "editor":
            editor(state)
        case "file":
            editor(state, file: DemoLaunch.file ?? "src/main.rs", line: 1)
            if DemoLaunch.scroll {
                DemoLaunch.after(1.5) { autoScroll(step: 0) }
            }
        case "completion":
            editor(state)
            DemoLaunch.after(1.0) { completion(state) }
        case "hover":
            editor(state)
            DemoLaunch.after(1.0) { hover() }
        case "quickopen":
            editor(state)
            DemoLaunch.after(0.8) { quickOpen(state) }
        case "symbols":
            editor(state)
            DemoLaunch.after(0.8) { symbols(state) }
        case "find":
            editor(state)
            DemoLaunch.after(0.8) { find(state) }
        case "problems":
            editor(state, file: "src/util.rs", line: 2)
            DemoLaunch.after(0.8) { problems(state) }
        case "preview":
            editor(state, file: "README.md", line: 1)
            DemoLaunch.after(0.8) {
                state.showPreview = true
                state.refreshPreview()
            }
        case "outline":
            state.prefs.outlinePanel = true
            editor(state)
        case "light":
            state.prefs.theme = "light"
            state.applyTheme()
            editor(state)
        default:
            break
        }
    }

    private static func autoScroll(step: Int) {
        guard step < 40 else {
            return
        }
        EditorJump.shared.jump(toLine: 1 + step * 400)
        DemoLaunch.after(0.1) { autoScroll(step: step + 1) }
    }

    private static func editor(_ state: AppState, file: String = "src/main.rs", line: Int = 9) {
        guard let root = state.workspaceRoot else {
            return
        }
        state.openFile(root.appendingPathComponent(file))
        DemoLaunch.after(0.6) {
            EditorJump.shared.jump(toLine: line)
        }
    }

    private static func completion(_ state: AppState) {
        guard let view = EditorJump.shared.view else {
            return
        }
        let ns = view.string as NSString
        let anchor = ns.range(of: "counter.record(\"ride\");")
        guard anchor.location != NSNotFound else {
            return
        }
        let end = NSMaxRange(anchor)
        EditorJump.shared.select(NSRange(location: end, length: 0))
        view.insertText("\n    let m: HashM", replacementRange: NSRange(location: end, length: 0))
        DemoLaunch.after(0.1) {
            CompletionSession.shared.trigger(view: view)
        }
    }

    private static func hover() {
        guard let view = EditorJump.shared.view else {
            return
        }
        let range = (view.string as NSString).range(of: "HashMap")
        guard range.location != NSNotFound else {
            return
        }
        HoverController.shared.present(view: view, range: range)
    }

    private static func quickOpen(_ state: AppState) {
        state.toggleQuickOpen()
        state.quickQuery = "ma"
        state.refreshQuickOpen()
    }

    private static func symbols(_ state: AppState) {
        state.toggleSymbolPicker()
        state.symbolPicker.query = "Has"
        state.symbolPicker.refresh()
    }

    private static func find(_ state: AppState) {
        state.toggleProjectFind()
        state.projectFind.query = "counter"
        state.projectFind.run(root: state.workspaceRoot, showHidden: state.prefs.showHidden)
    }

    private static func problems(_ state: AppState) {
        state.showProblems = true
        state.runCheck()
    }
}
