import AppKit

extension DemoScene {
    static func semantic(_ name: String, state: AppState) -> Bool {
        switch name {
        case "members":
            editor(state)
            DemoLaunch.after(1.0) {
                members(state, anchor: "fn main() {", typed: "\n    let parts: Vec<&str> = \"a.b\".split('.').", expected: "collect")
            }
        case "cppmembers":
            editor(state, file: "src/main.cpp", line: 20)
            DemoLaunch.after(1.0) {
                members(state, anchor: "std::vector<geo::Rect> rects = {rect, square};", typed: "\n    auto it = rects.begin();\n    it->", expected: "is_square")
            }
        case "typeinfo":
            editor(state)
            DemoLaunch.after(1.0) { typeInfo(state) }
        default:
            return false
        }
        return true
    }

    private static func members(_ state: AppState, anchor: String, typed: String, expected: String) {
        state.prefs.cheatSheet = false
        let e = SelfTestEditor(state: state)
        e.activate()
        e.place(on: anchor, atEnd: true)
        e.type(typed)
        retry(every: 2, until: { memberNames().contains(expected) }) {
            if let view = EditorPanes.shared.focusedView {
                CompletionSession.shared.trigger(view: view)
            }
        }
    }

    private static func typeInfo(_ state: AppState) {
        let e = SelfTestEditor(state: state)
        e.activate()
        retry(every: 2, until: { (EditorPanes.shared.focused?.docs.html ?? "").contains("Counter") }) {
            e.place(on: "let mut counter")
            e.view.map { $0.setSelectedRange(NSRange(location: $0.selectedRange().location + 8, length: 0)) }
            DocController.showTypeInfoFocused()
        }
    }

    private static func memberNames() -> [String] {
        guard CompletionSession.shared.isVisible else {
            return []
        }
        return CompletionSession.shared.list?.base.map(\.name) ?? []
    }

    private static func retry(every seconds: Double, until done: @escaping () -> Bool, attempt: @escaping () -> Void, deadline: Date = Date().addingTimeInterval(150)) {
        guard !done(), Date() < deadline else {
            ready(after: 0.8)
            return
        }
        attempt()
        DemoLaunch.after(seconds) { retry(every: seconds, until: done, attempt: attempt, deadline: deadline) }
    }
}
