import AppKit

extension SelfTestSteps {
    static func moveStatementSteps(
        state: AppState,
        e: SelfTestEditor,
        scratch: SelfTestScratch,
        file: String,
        source: String,
        first: String,
        second: String
    ) -> [SelfTestStep] {
        let name = (file as NSString).lastPathComponent
        return [
            SelfTestStep(name: "move statement open", wait: 1.0, run: {
                state.closeSplit()
                if let url = state.workspaceRoot?.appendingPathComponent(file) {
                    state.openFile(url)
                }
                e.activate()
                e.focus()
            }, check: {
                e.expect(
                    state.activeBuffer?.fileURL?.lastPathComponent == name && e.view != nil,
                    "active \(state.activeBuffer?.fileURL?.lastPathComponent ?? "nil")"
                )
            }),
            SelfTestStep(name: "move statement prep", wait: 1.0, run: {
                e.activate()
                e.focus()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                let full = NSRange(location: 0, length: (view.string as NSString).length)
                view.insertText(source, replacementRange: full)
                view.undoManager?.removeAllActions()
                view.breakUndoCoalescing()
                if let binding = view.hooks.binding?() {
                    SessionService.shared.resync(document: binding.document, view: view)
                }
            }, check: {
                e.expect(
                    e.view?.hooks.binding?()?.document.sessionId != nil
                        && e.text.contains(first)
                        && e.text.contains(second),
                    "session \(String(describing: e.view?.hooks.binding?()?.document.sessionId)) text \(e.text)"
                )
            }),
            SelfTestStep(name: "move statement down", wait: 0.4, run: {
                e.activate()
                e.place(on: first)
                EditorCommands.moveStatement(up: false)
            }, check: {
                moveOrder(e: e, first: first, second: second, firstAfter: true)
            }),
            SelfTestStep(name: "move statement up", wait: 0.4, run: {
                EditorCommands.moveStatement(up: true)
            }, check: {
                moveOrder(e: e, first: first, second: second, firstAfter: false)
            }),
            SelfTestStep(name: "move statement cleanup", run: {
                guard let view = e.view else {
                    return
                }
                let full = NSRange(location: 0, length: (view.string as NSString).length)
                view.insertText(scratch.saved, replacementRange: full)
                if let binding = view.hooks.binding?() {
                    SessionService.shared.resync(document: binding.document, view: view)
                }
            }, check: {
                e.expect(e.text == scratch.saved, "not restored")
            }),
        ]
    }

    private static func moveOrder(
        e: SelfTestEditor,
        first: String,
        second: String,
        firstAfter: Bool
    ) -> String? {
        let a = e.lines.firstIndex { $0.contains(first) }
        let b = e.lines.firstIndex { $0.contains(second) }
        let caretOnMoved = e.line(e.caretLine).contains(first)
        let order = a != nil && b != nil && (firstAfter ? a! > b! : a! < b!)
        return e.expect(
            order && caretOnMoved,
            "first \(String(describing: a)) second \(String(describing: b)) caret \(e.caretLine) \(e.line(e.caretLine))"
        )
    }
}
