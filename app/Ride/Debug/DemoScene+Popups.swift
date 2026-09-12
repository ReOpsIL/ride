import AppKit

extension DemoScene {
    static func popups(_ name: String, state: AppState) -> Bool {
        switch name {
        case "completion":
            editor(state)
            DemoLaunch.after(1.0) { completion(state) }
            ready(after: 2.4)
        case "cheatsheet":
            editor(state)
            DemoLaunch.after(1.0) { cheatSheet(state) }
            ready(after: 2.6)
        case "unformatted":
            editor(state)
            DemoLaunch.after(1.5) { unformat() }
            ready(after: 2.4)
        case "tools":
            editor(state)
            DemoLaunch.after(1.0) { state.showToolsSheet = true }
            ready(after: 2.0)
        case "hover":
            editor(state)
            DemoLaunch.after(1.0) { hover() }
            ready(after: 2.4)
        case "quickopen":
            editor(state)
            DemoLaunch.after(0.8) { quickOpen(state) }
            ready(after: 2.0)
        case "symbols":
            editor(state)
            DemoLaunch.after(0.8) { symbols(state) }
            ready(after: 2.0)
        case "find":
            editor(state)
            DemoLaunch.after(0.8) { find(state) }
            ready(after: 2.4)
        case "problems":
            editor(state)
            DemoLaunch.after(1.2) { problems(state) }
            ready(when: { CheckService.shared.hasRun && !CheckService.shared.running })
        default:
            return false
        }
        return true
    }

    private static func unformat() {
        guard let view = EditorPanes.shared.focusedView else {
            return
        }
        let anchor = (view.string as NSString).range(of: "counter.record(\"ride\");")
        view.replaceText(in: anchor, with: "counter.record(   \"ride\"  );")
    }

    private static func completion(_ state: AppState) {
        typeThenComplete(state, after: "counter.record(\"ride\");", text: "\n    let m: HashM")
    }

    private static func cheatSheet(_ state: AppState) {
        typeThenComplete(state, after: "counter.record(\"ride\");", text: "\n    ma")
    }

    static func typeThenComplete(_ state: AppState, after anchor: String, text: String) {
        guard let view = EditorPanes.shared.focusedView else {
            return
        }
        let range = (view.string as NSString).range(of: anchor)
        guard range.location != NSNotFound else {
            return
        }
        let end = NSMaxRange(range)
        EditorPanes.shared.focused?.select(NSRange(location: end, length: 0))
        view.insertText(text, replacementRange: NSRange(location: end, length: 0))
        DemoLaunch.after(0.2) {
            CompletionSession.shared.trigger(view: view)
        }
    }

    private static func hover() {
        guard let view = EditorPanes.shared.focusedView else {
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
        let e = SelfTestEditor(state: state)
        e.place(on: "let mut counter = Counter::new();", atEnd: true)
        e.type("\n    let _ride_total: u32 = \"demo\";")
        state.saveAll()
        state.showProblems = true
        state.runCheck()
    }
}
