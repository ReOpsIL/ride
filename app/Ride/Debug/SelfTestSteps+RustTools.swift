import AppKit

extension SelfTestSteps {
    static func rustTools(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> [SelfTestStep] {
        [
            goToLine(state: state, e: e, file: file),
            back(state: state, e: e, file: file),
            forward(state: state, e: e, file: file),
            SelfTestStep(name: "next method", run: { e.caret(line: 1); state.nextMethod(1) }, check: { e.expect(e.caretLine == 8, "caret \(e.caretLine)") }),
            SelfTestStep(name: "copy reference", run: { state.copyReference() }, check: { e.expect(NSPasteboard.general.string(forType: .string) == "src/main.rs:8", "pasteboard: \(NSPasteboard.general.string(forType: .string) ?? "nil")") }),
            SelfTestStep(name: "find next", run: { state.findQuery = "engine"; state.findOptions = .defaults; state.findOrigin = 0; state.findNext() }, check: { e.expect(e.selectedText == "engine", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "replace all", run: { state.findQuery = "ride"; state.replaceQuery = "RIDE"; state.replaceAll() }, check: { e.expect(e.line(10).contains("RIDE") && e.line(12).contains("RIDE"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "replace back", run: { state.findQuery = "RIDE"; state.replaceQuery = "ride"; state.replaceAll() }, check: { e.expect(e.line(10).contains("\"ride\"") && !e.text.contains("RIDE"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "format document", wait: 3.0, run: {
                e.view?.replaceText(in: e.lineRange(10), with: "    counter.record(   \"ride\"  );\n")
                state.formatActive()
            }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");" && state.formatError == nil, "line 10: \(e.line(10)) error \(state.formatError ?? "-")") }),
            SelfTestStep(name: "fold", run: { e.caret(line: 9); FoldController.shared.fold() }, check: { e.expect(e.view?.folds.ranges.count == 1, "folds \(e.view?.folds.ranges.count ?? -1)") }),
            SelfTestStep(name: "unfold all", run: { FoldController.shared.unfoldAll() }, check: { e.expect(e.view?.folds.isEmpty == true, "folds remain") }),
            SelfTestStep(name: "gutter fold", run: { FoldController.shared.toggle(line: 8) }, check: {
                e.expect(e.view?.folds.ranges.count == 1 && e.view?.folds.isFoldStart(line: 8) == true, "folds \(e.view?.folds.ranges.count ?? -1) start \(e.view?.folds.isFoldStart(line: 8) ?? false)")
            }),
            SelfTestStep(name: "gutter unfold", run: { FoldController.shared.toggle(line: 8) }, check: { e.expect(e.view?.folds.isEmpty == true, "folds remain") }),
            SelfTestStep(name: "surround", run: { e.caret(line: 10, column: 24); EditorCommands.selectWord(); if let t = EditorCommands.target() { EditorCommand.apply(SurroundWith.apply(SurroundTemplate(title: "(", open: "(", close: ")"), to: t), to: t.view) } }, check: { e.expect(e.line(10).contains("\"(ride)\"") && e.selectedText == "ride", "line 10: \(e.line(10)) sel \(e.selectedText)") }),
        ]
    }
}
