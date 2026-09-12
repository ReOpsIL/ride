import AppKit

extension SelfTestSteps {
    static func rust(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [setup(e: e, file: file, scratch: scratch)]
            + rustRun(state: state, e: e, scratch: scratch)
            + rustEdit(e: e, file: file, scratch: scratch)
            + rustSelect(e: e)
            + rustTools(state: state, e: e, file: file)
            + rustClose(state: state, e: e, file: file)
    }

    private static func rustRun(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            projectTargets(state: state, e: e),
            buildTarget(state: state, e: e),
            runTarget(state: state, e: e),
            buildDiagnostic(state: state, e: e, scratch: scratch),
            buildDiagnosticCleared(state: state, e: e, scratch: scratch),
        ]
    }

    private static func rustEdit(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            indentKeeps(e: e, file: file, scratch: scratch),
            unindentKeeps(e: e, file: file, scratch: scratch),
            tabInserts(e: e, file: file, scratch: scratch),
            undoOneStep(e: e, file: file, scratch: scratch),
            SelfTestStep(name: "comment line", run: { e.caret(line: 10); EditorCommands.commentLine() }, check: { e.expect(e.line(10) == "    // counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "uncomment line", run: { EditorCommands.commentLine() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "comment block", run: { e.selectLines(10, 11); EditorCommands.commentBlock() }, check: { e.expect(e.line(10) == "    " + blockOpen + " counter.record(\"ride\");" && e.line(11).hasSuffix("\"engine\"); " + blockClose), "\(e.line(10)) | \(e.line(11))") }),
            SelfTestStep(name: "uncomment block", run: { EditorCommands.commentBlock() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");" && e.line(11) == "    counter.record(\"engine\");", "\(e.line(10)) | \(e.line(11))") }),
            duplicateLine(e: e, file: file, scratch: scratch),
            deleteLine(e: e, file: file, scratch: scratch),
            SelfTestStep(name: "join lines", run: { e.caret(line: 9); EditorCommands.joinLines() }, check: { e.expect(e.line(9).contains("new(); counter.record"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "undo join", run: { e.view?.undoManager?.undo() }, check: { e.expect(e.line(10).contains("ride") && !e.line(9).contains("record"), "line 9: \(e.line(9))") }),
            moveLineDown(e: e, file: file, scratch: scratch),
            moveLineUp(e: e, file: file, scratch: scratch),
            SelfTestStep(name: "new line after", run: { e.caret(line: 10, column: 3); EditorCommands.newLine(before: false) }, check: { e.expect(e.line(11) == "    " && e.caretLine == 11, "line 11: '\(e.line(11))' caret \(e.caretLine)") }),
            SelfTestStep(name: "new line before", run: { EditorCommands.deleteLines(); e.caret(line: 10, column: 6); EditorCommands.newLine(before: true) }, check: { e.expect(e.line(10) == "    " && e.line(11).contains("ride"), "line 10: '\(e.line(10))'") }),
            SelfTestStep(name: "toggle case", run: { EditorCommands.deleteLines(); e.caret(line: 10, column: 7); EditorCommands.toggleCase() }, check: { e.expect(e.line(10).contains("COUNTER.record"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "toggle case back", run: { EditorCommands.toggleCase() }, check: { e.expect(e.line(10).contains("counter.record"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "sort lines", run: { e.selectLines(10, 12); EditorCommands.sortLines() }, check: { e.expect(e.line(10).contains("engine"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "undo sort", run: { e.view?.undoManager?.undo() }, check: { e.expect(e.line(10).contains("ride") && e.line(11).contains("engine"), "line 10: \(e.line(10))") }),
        ]
    }

    private static func rustSelect(e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "select word", run: { e.caret(line: 10, column: 14); EditorCommands.selectWord() }, check: { e.expect(e.selectedText == "record", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "extend selection", run: { EditorCommands.extendSelection() }, check: { e.expect(e.selectedText.count > 6 && e.selectedText.contains("record"), "selected: \(e.selectedText)") }),
            SelfTestStep(name: "shrink selection", run: { EditorCommands.shrinkSelection() }, check: { e.expect(e.selectedText == "record", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "select line", run: { EditorCommands.selectLine() }, check: { e.expect(e.selectedText.hasSuffix("\n") && e.selectedText.contains("ride"), "selected: \(e.selectedText)") }),
            SelfTestStep(name: "matching brace", run: { e.caret(line: 8, column: 12); EditorCommands.matchingBrace() }, check: { e.expect(e.caretLine == 20, "caret \(e.caretLine)") }),
            SelfTestStep(name: "smart newline", run: { e.caret(line: 8, column: 12); e.view?.insertNewline(nil) }, check: { e.expect(e.line(9) == "    " && e.caretLine == 9, "line 9: '\(e.line(9))' caret \(e.caretLine)") }),
            SelfTestStep(name: "closing brace dedent", run: { e.view?.insertText("}", replacementRange: NSRange(location: NSNotFound, length: 0)) }, check: { e.expect(e.line(9) == "}", "line 9: '\(e.line(9))'") }),
            SelfTestStep(name: "cleanup brace", run: { EditorCommands.deleteLines() }, check: { e.expect(e.line(9).contains("Counter::new"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "bracket pairing", run: { e.caret(line: 10, column: 28); e.view?.insertText("(", replacementRange: NSRange(location: NSNotFound, length: 0)) }, check: { e.expect(e.line(10).hasSuffix(";()") && e.caretLine == 10, "line 10: \(e.line(10))") }),
            SelfTestStep(name: "pair backspace", run: { e.view?.deleteBackward(nil) }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
        ]
    }

    private static func rustTools(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> [SelfTestStep] {
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

    private static func rustClose(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> [SelfTestStep] {
        [
            zoomIn(state: state, e: e),
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
            workspaceOpenSecond(state: state, e: e, file: file),
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

    private static func projectTargets(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "project targets", wait: 0.5, until: { !state.projectModel.rows.isEmpty }, timeout: 60, run: {}, check: {
            state.selectTarget(state.projectModel.rows.first { $0.kind == .bin })
            let bins = state.projectModel.rows.filter { $0.kind == .bin }
            return e.expect(
                bins.count == 1 && state.menu.selectedTarget == bins.first?.name,
                "targets \(state.projectModel.rows.map(\.id)) selected \(state.menu.selectedTarget ?? "nil")"
            )
        })
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
