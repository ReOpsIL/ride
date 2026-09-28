import AppKit

final class SemanticScratch {
    var start = 0
}

struct SemanticCase {
    let label: String
    let file: String
    let anchor: String
    let typed: String
    let expected: String

    static let rust = SemanticCase(
        label: "",
        file: "src/main.rs",
        anchor: "fn main() {",
        typed: "\n    let _parts: Vec<&str> = \"a.b\".split('.').",
        expected: "collect"
    )

    static let cpp = SemanticCase(
        label: " cpp",
        file: "src/main.cpp",
        anchor: "std::vector<geo::Rect> rects = {rect, square};",
        typed: "\n    auto it = rects.begin();\n    it->",
        expected: "is_square"
    )
}

extension SelfTestSteps {
    static func semanticSteps(state: AppState, e: SelfTestEditor, c: SemanticCase = .rust) -> [SelfTestStep] {
        let s = SemanticScratch()
        return [semanticOpen(state: state, e: e, c: c), semanticMembers(state: state, e: e, c: c, s: s)]
    }

    private static func semanticOpen(state: AppState, e: SelfTestEditor, c: SemanticCase) -> SelfTestStep {
        let name = (c.file as NSString).lastPathComponent
        return SelfTestStep(name: "semantic open\(c.label) main", until: {
            state.activeBuffer?.fileURL?.lastPathComponent == name && e.text.contains(c.anchor)
        }, timeout: 4, run: {
            let root = state.workspaceRoot ?? URL(fileURLWithPath: "/")
            state.openFile(root.appendingPathComponent(c.file))
        }, check: {
            e.expect(e.text.contains(c.anchor), "\(name) not active")
        })
    }

    private static func semanticMembers(state: AppState, e: SelfTestEditor, c: SemanticCase, s: SemanticScratch) -> SelfTestStep {
        SelfTestStep(name: "semantic\(c.label) member completion", until: { memberNames().contains(c.expected) }, timeout: 120, run: {
            PreferenceBindings(state: state).bool(\.semanticCompletion).wrappedValue = true
            e.activate()
            e.place(on: c.anchor, atEnd: true)
            s.start = e.view?.selectedRange().location ?? 0
            e.type(c.typed)
        }, check: {
            let names = memberNames()
            removeTyped(e, s, c)
            return e.expect(names.contains(c.expected), "members \(names.prefix(8))")
        })
    }

    private static func memberNames() -> [String] {
        guard CompletionSession.shared.isVisible else {
            return []
        }
        return CompletionSession.shared.list?.base.map(\.name) ?? []
    }

    private static func removeTyped(_ e: SelfTestEditor, _ s: SemanticScratch, _ c: SemanticCase) {
        CompletionSession.shared.dismiss()
        let range = NSRange(location: s.start, length: (c.typed as NSString).length)
        e.view?.insertText("", replacementRange: range)
    }
}
