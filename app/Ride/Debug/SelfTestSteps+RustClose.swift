import AppKit

extension SelfTestSteps {
    static func rustClose(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            zoomIn(state: state, e: e, scratch: scratch),
            zoomReset(state: state, e: e),
            SelfTestStep(name: "recent files", run: {}, check: { e.expect(state.recentFiles.first?.lastPathComponent == "main.rs", "recent \(state.recentFiles)") }),
            SelfTestStep(name: "tree keys", run: {}, check: {
                e.expect(
                    TreeModel.action(keyCode: TreeModel.delete) == .trash
                        && TreeModel.action(keyCode: TreeModel.return) == .rename,
                    "delete \(String(describing: TreeModel.action(keyCode: TreeModel.delete))) return \(String(describing: TreeModel.action(keyCode: TreeModel.return)))"
                )
            }),
            runEcho(state: state, e: e),
            runOutputLinks(state: state, e: e),
            runBigOutput(state: state, e: e),
            runOutputClose(state: state, e: e),
            terminalOpen(state: state, e: e),
            terminalClose(state: state, e: e),
            SelfTestStep(name: "save all", run: { state.saveAll() }, check: { e.expect(state.activeBuffer?.isDirty == false, "still dirty") }),
        ] + workspaceOpenSecond(state: state, e: e, file: file, scratch: scratch) + [
            workspaceRestore(state: state, e: e, file: file),
            targetSelectionRestore(state: state, e: e),
            workspaceSnapshotAfterOpen(state: state, e: e),
            outerSignatureAfterClose(e: e),
            splitHeaderSource(state: state, e: e),
            quickDocOpen(state: state, e: e),
            quickDoc(state: state, e: e),
            docPin(e: e),
            completionDocTrigger(e: e),
            completionDoc(e: e),
            docCleanup(),
            docWebViewReleases(e: e),
            quickDefinitionOpen(state: state, e: e),
            quickDefinition(state: state, e: e),
            peekCleanup(),
        ]
    }

    private static func terminalOpen(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "terminal open", wait: 0.5, run: { state.openTerminal(directory: state.workspaceRoot) }, check: {
            e.expect(
                state.showTerminal && state.menu.showTerminal && state.terminals.tabs.count == 1,
                "tabs \(state.terminals.tabs.count) shown \(state.showTerminal)"
            )
        })
    }

    private static func terminalClose(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "terminal close", wait: 0.5, run: {
            guard let id = state.terminals.tabs.selected else {
                return
            }
            state.terminals.close(id)
            state.showTerminal = false
            e.focus()
        }, check: {
            e.expect(
                state.terminals.tabs.isEmpty && !state.showTerminal,
                "tabs \(state.terminals.tabs.count) shown \(state.showTerminal)"
            )
        })
    }

    private static func outerSignatureAfterClose(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "outer signature after )", wait: 1.0, run: {
            guard let view = e.view else {
                return
            }
            let prefix = "\nfn f(a: i32, b: i32) {}\nfn g(x: i32) {}\nfn _sig() { "
            let start = (view.string as NSString).length
            view.insertText(prefix, replacementRange: NSRange(location: start, length: 0))
            view.setSelectedRange(NSRange(location: start + (prefix as NSString).length, length: 0))
            e.type("f(g(1), ")
        }, check: {
            let name = SignatureHelpController.shared.activeName ?? "nil"
            return e.expect(
                SignatureHelpController.shared.isVisible && SignatureHelpController.shared.activeName == "f",
                "sig \(name) visible \(SignatureHelpController.shared.isVisible)"
            )
        })
    }
}
