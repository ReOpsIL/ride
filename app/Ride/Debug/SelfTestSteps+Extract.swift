import AppKit

extension SelfTestSteps {
    static func rustExtract(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        extractSteps(e: e, scratch: scratch, needle: "HashMap::new()", declaration: "    let value = HashMap::new();")
    }

    static func cppExtract(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [openShapes(state: state, e: e)]
            + extractSteps(
                e: e,
                scratch: scratch,
                needle: "std::fabs(width_ - height_)",
                declaration: "    auto value = std::fabs(width_ - height_);"
            )
    }

    private static func openShapes(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "extract open shapes", wait: 1.0, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            e.activate()
        }, check: {
            e.expect(e.text.contains("std::fabs(width_ - height_)"), "active \(state.activeBuffer?.fileURL?.lastPathComponent ?? "nil")")
        })
    }

    private static func extractSteps(e: SelfTestEditor, scratch: SelfTestScratch, needle: String, declaration: String) -> [SelfTestStep] {
        [
            SelfTestStep(name: "extract prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view, let binding = view.hooks.binding?() else {
                    return
                }
                scratch.saved = view.string
                SessionService.shared.resync(document: binding.document, view: view)
            }, check: { e.expect(e.text.contains(needle) && !e.text.contains("let value"), "no \(needle)") }),
            SelfTestStep(name: "extract variable", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                let range = (view.string as NSString).range(of: needle)
                guard range.location != NSNotFound else {
                    return
                }
                view.setSelectedRange(range)
                EditorCommands.extractVariable()
            }, check: {
                e.expect(
                    e.lines.contains(declaration) && e.text.contains("value") && e.selectedText == "value",
                    "selected '\(e.selectedText)' lines \(e.lines.filter { $0.contains("value") })"
                )
            }),
            SelfTestStep(name: "extract undo", until: { !e.lines.contains(declaration) }, timeout: 10, run: { e.view?.undoManager?.undo() }, check: {
                e.expect(!e.lines.contains(declaration), "declaration remains")
            }),
            SelfTestStep(name: "extract cleanup", run: {
                guard let view = e.view else {
                    return
                }
                let full = NSRange(location: 0, length: (view.string as NSString).length)
                view.insertText(scratch.saved, replacementRange: full)
                if let binding = view.hooks.binding?() {
                    SessionService.shared.resync(document: binding.document, view: view)
                }
            }, check: { e.expect(e.text == scratch.saved && e.text.contains(needle), "not restored") }),
        ]
    }
}
