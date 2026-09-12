import AppKit

extension SelfTestSteps {
    private static let completeBody = "return PI * radius_ * radius_"

    static func cpp(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            setup(e: e, file: file, scratch: scratch),
            indentKeeps(e: e, file: file, scratch: scratch),
            unindentKeeps(e: e, file: file, scratch: scratch),
            tabInserts(e: e, file: file, scratch: scratch),
            undoOneStep(e: e, file: file, scratch: scratch),
            duplicateLine(e: e, file: file, scratch: scratch),
            deleteLine(e: e, file: file, scratch: scratch),
            moveLineDown(e: e, file: file, scratch: scratch),
            moveLineUp(e: e, file: file, scratch: scratch),
            commentLine(e: e),
            uncommentLine(e: e),
            engineReady(e: e),
            matchingBrace(e: e),
            fold(e: e),
            unfold(e: e),
            cppQuickDefinitionOpen(state: state, e: e),
            cppQuickDefinition(state: state, e: e),
            peekCleanup(),
            completeStatementPrep(e: e),
            completeStatement(e: e),
            completeStatementCleanup(e: e),
            goToLine(state: state, e: e, file: file),
            back(state: state, e: e, file: file),
            forward(state: state, e: e, file: file),
            zoomIn(state: state, e: e),
            zoomReset(state: state, e: e),
            workspaceOpenSecond(state: state, e: e, file: file),
            workspaceRestore(state: state, e: e, file: file),
            workspaceSnapshotAfterOpen(state: state, e: e),
            headerSourceSwitch(state: state, e: e),
            runFileError(state: state, e: e),
            recompileFile(state: state, e: e),
        ]
    }

    private static func commentLine(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "comment line", run: {
            e.focus()
            e.place(on: "std::ostringstream out;")
            EditorCommands.commentLine()
        }, check: { e.expect(e.line(15) == "    // std::ostringstream out;", "line 15: \(e.line(15))") })
    }

    private static func uncommentLine(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "uncomment line", run: { EditorCommands.commentLine() }, check: {
            e.expect(e.line(15) == "    std::ostringstream out;", "line 15: \(e.line(15))")
        })
    }

    private static func engineReady(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "engine session", wait: 1.5, run: {
            e.activate()
            guard let view = e.view, let binding = view.hooks.binding?() else {
                return
            }
            SessionService.shared.resync(document: binding.document, view: view)
        }, check: {
            e.expect(e.view?.hooks.binding?()?.document.sessionId != nil, "no session")
        })
    }

    private static func matchingBrace(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "matching brace", wait: 0.4, run: {
            e.activate()
            e.caret(line: 22, column: 27)
            EditorCommands.matchingBrace()
        }, check: {
            e.expect(e.line(e.caretLine).trimmingCharacters(in: .whitespaces) == "}", "caret \(e.caretLine) \(e.line(e.caretLine))")
        })
    }

    private static func completeStatementPrep(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "complete statement prep", wait: 0.8, run: {
            e.activate()
            e.place(on: "return name_;", atEnd: true)
            EditorCommands.newLine(before: false)
            e.type("int x = 1")
        }, check: {
            e.expect(e.line(e.caretLine).contains("int x = 1") && !e.line(e.caretLine).contains(";"), "line '\(e.line(e.caretLine))'")
        })
    }

    private static func completeStatement(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "complete statement", wait: 0.8, run: {
            e.activate()
            EditorCommands.completeStatement()
        }, check: { e.expect(e.line(e.caretLine).contains("int x = 1;"), "line '\(e.line(e.caretLine))'") })
    }

    private static func completeStatementCleanup(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "complete statement cleanup", run: {
            e.activate()
            EditorCommands.deleteLines()
        }, check: { e.expect(!e.text.contains("int x = 1"), "leftover") })
    }

    private static func fold(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "fold", run: {
            e.activate()
            e.place(on: completeBody)
            FoldController.shared.fold()
        }, check: { e.expect(e.view?.folds.ranges.count == 1, "folds \(e.view?.folds.ranges.count ?? -1)") })
    }

    private static func unfold(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "unfold all", run: { FoldController.shared.unfoldAll() }, check: {
            e.expect(e.view?.folds.isEmpty == true, "folds remain")
        })
    }

    private static func cppQuickDefinitionOpen(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick definition open", wait: 1.5, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            e.focus()
        }, check: { e.expect(e.text.contains("Circle::area"), "no Circle::area") })
    }

    private static func cppQuickDefinition(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick definition", wait: 1.2, run: {
            e.activate()
            e.caret(line: 22, column: 14)
            state.showQuickDefinition()
        }, check: {
            let peek = EditorPanes.shared.focused?.peek
            let text = peek?.excerptText ?? ""
            let labels = peek?.labels ?? []
            return e.expect(
                peek?.isVisible == true && text.contains("Circle::area") && labels.count >= 2,
                "visible \(peek?.isVisible ?? false) labels \(labels) text \(text.prefix(160))"
            )
        })
    }

    private static func runFileError(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run file error", wait: 0.8, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 120, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/main.cpp") {
                state.openFile(url)
            }
            state.runFile()
        }, check: {
            let text = state.runOutput.text
            return e.expect(
                state.runOutput.status != "exit 0" && text.lowercased().contains("error"),
                "status \(state.runOutput.status ?? "nil") text \(text.suffix(240))"
            )
        })
    }

    private static func recompileFile(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "recompile file", wait: 0.8, until: { !state.runOutput.isRunning && state.runOutput.status != nil }, timeout: 120, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            state.recompileFile()
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0",
                "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(240))"
            )
        })
    }

    private static func headerSourceSwitch(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "header source switch", wait: 0.8, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            state.switchHeaderSource()
        }, check: {
            let path = state.activeBuffer?.fileURL?.path ?? ""
            return e.expect(path.hasSuffix("include/shapes.hpp"), "path \(path)")
        })
    }
}
