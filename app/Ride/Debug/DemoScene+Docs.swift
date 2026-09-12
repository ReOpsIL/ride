import AppKit

extension DemoScene {
    static func docs(_ name: String, state: AppState) -> Bool {
        switch name {
        case "quickdoc":
            editor(state)
            DemoLaunch.after(1.4) { quickDoc(state) }
            ready(after: 3.0)
        case "peek":
            editor(state, file: "src/util.rs", line: 10)
            DemoLaunch.after(1.4) { peek(state) }
            ready(after: 3.0)
        case "split":
            editor(state)
            DemoLaunch.after(1.4) { split(state) }
            ready(after: 3.0)
        default:
            return false
        }
        return true
    }

    private static func quickDoc(_ state: AppState) {
        let e = SelfTestEditor(state: state)
        e.focus()
        e.place(on: "Counter::new")
        state.showQuickDocumentation()
    }

    private static func peek(_ state: AppState) {
        let e = SelfTestEditor(state: state)
        e.focus()
        e.place(on: "record(&mut")
        state.showQuickDefinition()
    }

    private static func split(_ state: AppState) {
        guard let sibling = splitSibling(state) else {
            return
        }
        state.openFile(sibling)
        DemoLaunch.after(0.6) {
            state.openInSplit()
            EditorPanes.shared.focused?.jump(toLine: 12)
        }
    }

    private static func splitSibling(_ state: AppState) -> URL? {
        guard let root = state.workspaceRoot else {
            return nil
        }
        let candidates = ["src/util.rs", "include/geo.h", "src/shapes.cpp", "src/util.c"]
        return candidates
            .map { root.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
