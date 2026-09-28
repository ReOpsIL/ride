import AppKit

final class SemanticScratch {
    var start = 0
}

extension SelfTestSteps {
    static let semanticLine = "\n    let _parts: Vec<&str> = \"a.b\".split('.')."

    static func semanticSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let s = SemanticScratch()
        return [semanticOpenMain(state: state, e: e), semanticMembers(state: state, e: e, s: s)]
    }

    private static func semanticOpenMain(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "semantic open main", until: {
            state.activeBuffer?.fileURL?.lastPathComponent == "main.rs" && e.text.contains("fn main() {")
        }, timeout: 4, run: {
            let root = state.workspaceRoot ?? URL(fileURLWithPath: "/")
            state.openFile(root.appendingPathComponent("src/main.rs"))
        }, check: {
            e.expect(e.text.contains("fn main() {"), "main.rs not active")
        })
    }

    private static func semanticMembers(state: AppState, e: SelfTestEditor, s: SemanticScratch) -> SelfTestStep {
        SelfTestStep(name: "semantic member completion", until: { memberNames().contains("collect") }, timeout: 120, run: {
            PreferenceBindings(state: state).bool(\.semanticCompletion).wrappedValue = true
            e.activate()
            e.place(on: "fn main() {", atEnd: true)
            s.start = e.view?.selectedRange().location ?? 0
            e.type(semanticLine)
        }, check: {
            let names = memberNames()
            removeTyped(e, s)
            return e.expect(names.contains("collect"), "members \(names.prefix(8))")
        })
    }

    private static func memberNames() -> [String] {
        guard CompletionSession.shared.isVisible else {
            return []
        }
        return CompletionSession.shared.list?.base.map(\.name) ?? []
    }

    private static func removeTyped(_ e: SelfTestEditor, _ s: SemanticScratch) {
        CompletionSession.shared.dismiss()
        let range = NSRange(location: s.start, length: (semanticLine as NSString).length)
        e.view?.insertText("", replacementRange: range)
    }
}
