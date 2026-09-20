import AppKit

extension SelfTestSteps {
    static func breakpointShiftSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            shiftSettle(state: state, e: e),
            shiftPrep(state: state, e: e),
            shiftInsert(state: state, e: e),
            shiftUndo(state: state, e: e),
            shiftCleanup(state: state, e: e),
        ]
    }

    private static var aboveLine: Int {
        Int(breakpointLine) - 1
    }

    private static func shiftView(_ state: AppState) -> RideTextView? {
        state.activeBuffer.flatMap { EditorPanes.shared.host(bound: $0)?.textView }
    }

    private static func lineStart(_ view: RideTextView, _ number: Int) -> Int {
        let starts = view.lineIndex().starts
        return starts[min(max(number, 1), starts.count) - 1]
    }

    private static func lineText(_ state: AppState, _ number: Int) -> String {
        guard let view = shiftView(state) else {
            return ""
        }
        let lines = view.string.components(separatedBy: "\n")
        return lines.indices.contains(number - 1) ? lines[number - 1] : ""
    }

    private static func shiftSettle(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint shift settle", wait: 1.5, until: {
            state.activeBuffer?.isDirty == false
        }, timeout: 30, run: {
            e.activate()
            state.closeSplit()
            state.saveAll()
        }, check: {
            e.expect(
                state.activeBuffer?.isDirty == false && EditorPanes.shared.all.count == 1,
                "dirty \(state.activeBuffer?.isDirty ?? true) panes \(EditorPanes.shared.all.count)"
            )
        })
    }

    private static func shiftPrep(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint shift prep", wait: 0.4, run: {
            e.activate()
            for host in EditorPanes.shared.all {
                host.textView.breakUndoCoalescing()
            }
            state.debug.breakpoints = Breakpoints()
            state.activeBuffer?.undoManager.removeAllActions()
            guard let view = shiftView(state) else {
                return
            }
            view.window?.makeFirstResponder(view)
            view.setSelectedRange(NSRange(location: lineStart(view, Int(breakpointLine)), length: 0))
            state.toggleBreakpointAtCaret()
        }, check: {
            e.expect(marks(state) == [breakpointLine], "marks \(marks(state))")
        })
    }

    private static func shiftInsert(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint shift insert", wait: 0.5, run: {
            guard let view = shiftView(state) else {
                return
            }
            view.window?.makeFirstResponder(view)
            let location = lineStart(view, aboveLine)
            view.setSelectedRange(NSRange(location: location, length: 0))
            view.breakUndoCoalescing()
            view.insertText("\n", replacementRange: NSRange(location: location, length: 0))
            view.breakUndoCoalescing()
        }, check: {
            e.expect(
                marks(state) == [breakpointLine + 1] && lineText(state, aboveLine).isEmpty,
                "marks \(marks(state)) line \(aboveLine) '\(lineText(state, aboveLine))'"
            )
        })
    }

    private static func shiftUndo(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint shift undo", wait: 0.5, run: {
            guard let view = shiftView(state) else {
                return
            }
            view.window?.makeFirstResponder(view)
            view.breakUndoCoalescing()
            view.undoManager?.undo()
        }, check: {
            e.expect(
                marks(state) == [breakpointLine] && !lineText(state, aboveLine).isEmpty,
                "marks \(marks(state)) line \(aboveLine) '\(lineText(state, aboveLine))'"
            )
        })
    }

    private static func shiftCleanup(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "breakpoint shift cleanup", wait: 0.3, run: {
            state.debug.breakpoints = Breakpoints()
            state.refreshBreakpointGutters()
        }, check: {
            e.expect(state.debug.breakpoints.isEmpty, "marks \(marks(state))")
        })
    }
}
