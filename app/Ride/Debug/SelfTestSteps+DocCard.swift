import AppKit

extension SelfTestSteps {
    static func docCardSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "doc card on quick documentation", wait: 0.3, until: { DocCardController.shared.isVisible }, timeout: 8, run: {
                resetDocCard(e, on: "Counter::new")
                state.showQuickDocumentation()
            }, check: {
                e.expect(DocCardController.shared.isVisible && !docsVisible, "card \(DocCardController.shared.isVisible) docs \(docsVisible)")
            }),
            SelfTestStep(name: "doc card click opens docs", wait: 0.3, until: { docsVisible }, timeout: 8, run: {
                _ = DocCardController.shared.upgrade()
            }, check: {
                e.expect(docsVisible && !DocCardController.shared.isVisible, "card \(DocCardController.shared.isVisible) docs \(docsVisible)")
            }),
            SelfTestStep(name: "doc card second press before the reply", wait: 0.3, until: { docsVisible }, timeout: 8, run: {
                resetDocCard(e, on: "Counter::new")
                state.showQuickDocumentation()
                state.showQuickDocumentation()
            }, check: {
                e.expect(docsVisible && DocCardController.shared.state == .idle, "card \(DocCardController.shared.state) docs \(docsVisible)")
            }),
            SelfTestStep(name: "doc card follows the caret", wait: 0.3, until: { DocCardController.shared.isVisible }, timeout: 8, run: {
                resetDocCard(e, on: "Counter::new")
                state.showQuickDocumentation()
            }, check: {
                e.place(on: "counter.record")
                state.showQuickDocumentation()
                let word = DocCardController.shared.state.word
                let caret = e.view?.selectedRange().location ?? -1
                let follows = word.map { NSLocationInRange(caret, $0) } ?? false
                DocCardController.shared.hide()
                return e.expect(follows && !docsVisible, "card \(String(describing: word)) caret \(caret) docs \(docsVisible)")
            }),
        ]
    }

    private static var docsVisible: Bool {
        EditorPanes.shared.focused?.docsStorage?.isVisible == true
    }

    private static func resetDocCard(_ e: SelfTestEditor, on needle: String) {
        DocCardController.shared.hide()
        EditorPanes.shared.focused?.docsStorage?.hide()
        e.activate()
        e.place(on: needle)
    }
}
