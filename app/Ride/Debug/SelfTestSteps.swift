import AppKit

enum SelfTestSteps {
    static let blockOpen = "/" + "*"
    static let blockClose = "*" + "/"

    static func all(state: AppState) -> [SelfTestStep] {
        let e = SelfTestEditor(state: state)
        let file = SelfTestOpened.from(state)
        let scratch = SelfTestScratch()
        let suites = [
            BufferLanguage.c: c(state: state, e: e, file: file, scratch: scratch),
            .cpp: cpp(state: state, e: e, file: file, scratch: scratch),
            .rust: rust(state: state, e: e, file: file, scratch: scratch),
        ]
        let language = state.activeBuffer?.language ?? .rust
        let steps = suites[language] ?? suites[.rust] ?? []
        let known = Set(suites.values.flatMap { $0.map(\.name) })
        return steps + [SelfTestMenuCoverage.step(state: state, suite: Set(steps.map(\.name)), known: known)]
    }

    static func setup(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "setup", wait: 1.5, run: {
            e.focus()
            scratch.body = e.line(file.bodyLine)
            scratch.next = e.line(file.bodyLine + 1)
        }, check: { e.expect(e.view != nil && e.lines.count > 15 && !scratch.body.isEmpty, "editor missing") })
    }

    static func indentKeeps(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "indent keeps selection", run: {
            e.selectLines(file.bodyLine, file.bodyLine)
            e.view?.insertTab(nil)
        }, check: {
            e.expect(
                e.line(file.bodyLine) == "    " + scratch.body && (e.view?.selectedRange().length ?? 0) > 0,
                "line \(file.bodyLine): \(e.line(file.bodyLine)) sel \(String(describing: e.view?.selectedRange()))"
            )
        })
    }

    static func unindentKeeps(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "unindent keeps selection", run: { e.view?.insertBacktab(nil) }, check: {
            e.expect(
                e.line(file.bodyLine) == scratch.body && (e.view?.selectedRange().length ?? 0) > 0,
                "line \(file.bodyLine): \(e.line(file.bodyLine))"
            )
        })
    }

    static func tabInserts(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "tab inserts spaces", run: { e.caret(line: file.bodyLine, column: 5); e.view?.insertTab(nil) }, check: {
            e.expect(e.line(file.bodyLine) == "    " + scratch.body, "line \(file.bodyLine): \(e.line(file.bodyLine))")
        })
    }

    static func undoOneStep(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "undo is one step", run: { e.undo() }, check: {
            e.expect(e.line(file.bodyLine) == scratch.body, "line \(file.bodyLine): \(e.line(file.bodyLine))")
        })
    }

    static func undoTypingRun(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "undo typing run is one step", run: {
            e.view?.breakUndoCoalescing()
            e.caret(line: file.bodyLine)
            e.type("q")
            e.view?.breakUndoCoalescing()
            e.place(on: scratch.body, atEnd: true)
            e.type("xyz")
            e.undo()
            e.undo()
        }, check: {
            e.expect(e.line(file.bodyLine) == scratch.body, "line \(file.bodyLine): \(e.line(file.bodyLine))")
        })
    }

    static func duplicateLine(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "duplicate line", run: { e.caret(line: file.bodyLine); EditorCommands.duplicate() }, check: {
            e.expect(e.line(file.bodyLine + 1) == e.line(file.bodyLine) && e.line(file.bodyLine) == scratch.body, "line \(file.bodyLine + 1): \(e.line(file.bodyLine + 1))")
        })
    }

    static func deleteLine(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "delete line", run: { EditorCommands.deleteLines() }, check: {
            e.expect(e.line(file.bodyLine + 1) == scratch.next, "line \(file.bodyLine + 1): \(e.line(file.bodyLine + 1))")
        })
    }

    static func moveLineDown(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "move line down", run: { e.caret(line: file.bodyLine); EditorCommands.moveLines(up: false) }, check: {
            e.expect(e.line(file.bodyLine) == scratch.next && e.line(file.bodyLine + 1) == scratch.body, "\(e.line(file.bodyLine)) | \(e.line(file.bodyLine + 1))")
        })
    }

    static func moveLineUp(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "move line up", run: { EditorCommands.moveLines(up: true) }, check: {
            e.expect(e.line(file.bodyLine) == scratch.body && e.caretLine == file.bodyLine, "\(e.line(file.bodyLine)) caret \(e.caretLine)")
        })
    }

    static func goToLine(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "go to line", run: {
            e.caret(line: file.bodyLine)
            state.goToLineQuery = "\(file.goToLine)"
            state.confirmGoToLine()
        }, check: { e.expect(e.caretLine == file.goToLine, "caret \(e.caretLine)") })
    }

    static func back(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "back", run: { state.goBack() }, check: { e.expect(e.caretLine == file.bodyLine, "caret \(e.caretLine)") })
    }

    static func forward(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "forward", run: { state.goForward() }, check: { e.expect(e.caretLine == file.goToLine, "caret \(e.caretLine)") })
    }

    static func zoomIn(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "zoom", run: { let before = state.prefs.fontSize; state.zoom(1); scratch.zoomBefore = before }, check: {
            e.expect(state.prefs.fontSize == scratch.zoomBefore + 1, "font \(state.prefs.fontSize)")
        })
    }

    static func zoomReset(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "zoom reset", run: { state.resetZoom() }, check: {
            e.expect(state.prefs.fontSize == Preferences.defaults.fontSize, "font \(state.prefs.fontSize)")
        })
    }
}
