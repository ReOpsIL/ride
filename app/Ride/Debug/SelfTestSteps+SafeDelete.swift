import AppKit

extension SelfTestSteps {
    static func safeDeleteSteps(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "safe delete prep", wait: 1.0, run: {
                e.activate()
                e.focus()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                let source = "fn unused_safe_delete() {}\n\nfn main() {}\n"
                let full = NSRange(location: 0, length: (view.string as NSString).length)
                view.insertText(source, replacementRange: full)
                view.undoManager?.removeAllActions()
                view.breakUndoCoalescing()
                resyncSession(e: e)
            }, check: {
                e.expect(e.text.contains("fn unused_safe_delete()") && e.text.contains("fn main()"), "no unused fn")
            }),
            SelfTestStep(name: "safe delete", wait: 0.4, until: {
                if !e.text.contains("unused_safe_delete") {
                    return true
                }
                e.focus()
                e.place(on: "unused_safe_delete")
                e.view?.breakUndoCoalescing()
                _ = RenameController.shared.applySafeDeleteDirect(state: state)
                return !e.text.contains("unused_safe_delete")
            }, timeout: 15, run: {
                e.activate()
                e.focus()
            }, check: {
                e.expect(
                    !e.text.contains("unused_safe_delete"),
                    "notice \(e.state.notice ?? "nil") leftover"
                )
            }),
            SelfTestStep(name: "safe delete undo", until: { e.text.contains("fn unused_safe_delete()") }, timeout: 10, run: {
                e.view?.undoManager?.undo()
            }, check: {
                e.expect(e.text.contains("fn unused_safe_delete()"), "fn missing after undo")
            }),
            SelfTestStep(name: "safe delete cleanup", run: {
                guard let view = e.view else {
                    return
                }
                let full = NSRange(location: 0, length: (view.string as NSString).length)
                view.insertText(scratch.saved, replacementRange: full)
                resyncSession(e: e)
            }, check: {
                e.expect(e.text == scratch.saved, "not restored")
            }),
        ]
    }

    private static func resyncSession(e: SelfTestEditor) {
        guard let view = e.view, let binding = view.hooks.binding?() else {
            return
        }
        SessionService.shared.resync(document: binding.document, view: view)
    }
}
