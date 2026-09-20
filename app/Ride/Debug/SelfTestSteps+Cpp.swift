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
            zoomIn(state: state, e: e, scratch: scratch),
            zoomReset(state: state, e: e),
        ] + workspaceOpenSecond(state: state, e: e, file: file, scratch: scratch) + [
            workspaceRestore(state: state, e: e, file: file),
            workspaceSnapshotAfterOpen(state: state, e: e),
            headerSourceSwitch(state: state, e: e),
            runFileError(state: state, e: e),
            recompileFile(state: state, e: e, relative: "src/shapes.cpp"),
            generatePrep(state: state, e: e, scratch: scratch),
            generateConstructor(e: e),
            generateGetters(e: e),
            generateCleanup(e: e, scratch: scratch),
        ] + liveSteps(state: state, e: e) + cppExtract(state: state, e: e, scratch: scratch)
            + cppRefactor(e: e, scratch: scratch) + cppDebugSteps(state: state, e: e)
            + moveStatementSteps(
                state: state,
                e: e,
                scratch: scratch,
                file: "src/shapes.cpp",
                source: "void ride_move() {\n    int move_a = 1;\n    int move_b = 2;\n}\n",
                first: "int move_a = 1;",
                second: "int move_b = 2;"
            )
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
            let lower = text.lowercased()
            let linked = lower.contains("undefined symbol") || lower.contains("linker command failed")
            return e.expect(
                state.runOutput.status != "exit 0" && linked && !lower.contains("file not found"),
                "status \(state.runOutput.status ?? "nil") text \(text.suffix(400))"
            )
        })
    }

    private static func generatePrep(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "generate prep", wait: 1.5, run: {
            if let url = state.workspaceRoot?.appendingPathComponent("src/shapes.cpp") {
                state.openFile(url)
            }
            e.activate()
            guard let view = e.view, let binding = view.hooks.binding?() else {
                return
            }
            scratch.saved = view.string
            let addition = "\n\nstruct GenBase {\n    int tag_;\n};\nstruct GenBox : GenBase {\n    std::string gname_;\n    int gy_;\n};\n"
            let end = (view.string as NSString).length
            view.setSelectedRange(NSRange(location: end, length: 0))
            view.insertText(addition, replacementRange: NSRange(location: end, length: 0))
            SessionService.shared.resync(document: binding.document, view: view)
        }, check: { e.expect(e.text.contains("struct GenBox"), "no GenBox") })
    }

    private static func generateConstructor(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "generate constructor", wait: 1.0, run: {
            e.activate()
            e.place(on: "int gy_;")
            EditorCommands.applyGenerator(.constructor)
        }, check: {
            e.expect(
                e.text.contains("GenBox(std::string gname, int gy) : gname_(gname), gy_(gy) {}")
                    && !e.text.contains("tag_("),
                "text \(e.text.suffix(260))"
            )
        })
    }

    private static func generateGetters(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "generate getters", wait: 0.8, run: {
            e.activate()
            e.place(on: "int gy_;")
            EditorCommands.applyGenerator(.getters)
        }, check: {
            e.expect(
                e.text.contains("std::string gname() const { return gname_; }"),
                "text \(e.text.suffix(260))"
            )
        })
    }

    private static func generateCleanup(e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "generate cleanup", run: {
            guard let view = e.view else {
                return
            }
            let full = NSRange(location: 0, length: (view.string as NSString).length)
            view.insertText(scratch.saved, replacementRange: full)
            if let binding = view.hooks.binding?() {
                SessionService.shared.resync(document: binding.document, view: view)
            }
        }, check: { e.expect(!e.text.contains("GenBox"), "leftover") })
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
