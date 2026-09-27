import AppKit

extension SelfTestSteps {
    static let sleepLine = 19
    static let sleepCode = "    std::thread::sleep(std::time::Duration::from_secs(20));"

    static func debugMenuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let scratch = SelfTestRunScratch()
        let live = DeveloperMode.isEnabled
            ? liveDebugMenu(state: state, e: e, scratch: scratch)
            : [SelfTestStep(name: "debug menu (skipped: developer mode disabled)", wait: 0.1, run: {}, check: { nil })]
        return [menuDebugPanel(state: state, e: e), debugPanelHide(state: state, e: e)] + exceptionFilterSteps(state: state, e: e)
            + [menuToggleBreakpoint(state: state, e: e, on: true)]
            + live + [menuToggleBreakpoint(state: state, e: e, on: false)]
    }

    private static func menuDebugPanel(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "menu debug panel", wait: 0.4, run: {
            if state.debugPanel.visible {
                state.debugPanel.visible = false
            }
            SelfTestMenu.perform("Debug › Debug Panel")
        }, check: {
            e.expect(
                state.debugPanel.visible && SelfTestMenu.isChecked("Debug › Debug Panel"),
                "visible \(state.debugPanel.visible) checked \(SelfTestMenu.isChecked("Debug › Debug Panel"))"
            )
        })
    }

    private static func debugPanelHide(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "debug panel hide button", wait: 0.4, run: {
            state.debugPanel.visible = false
        }, check: {
            e.expect(
                !state.menu.showDebugPanel && !SelfTestMenu.isChecked("Debug › Debug Panel"),
                "menu \(state.menu.showDebugPanel) checked \(SelfTestMenu.isChecked("Debug › Debug Panel"))"
            )
        })
    }

    private static func menuToggleBreakpoint(state: AppState, e: SelfTestEditor, on: Bool) -> SelfTestStep {
        SelfTestStep(name: on ? "menu toggle breakpoint" : "menu toggle breakpoint off", wait: 0.6, run: {
            openRelative(state, "src/main.rs")
            e.focus()
            e.caret(line: Int(breakpointLine))
            SelfTestMenu.perform("Debug › Toggle Breakpoint")
        }, check: {
            e.expect(marks(state) == (on ? [breakpointLine] : []), "marks \(marks(state))")
        })
    }

    private static func liveDebugMenu(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> [SelfTestStep] {
        [
            debugSleepEdit(state: state, e: e, insert: true),
            menuDebugWhileRunning(state: state, e: e, scratch: scratch),
        ] + debugEvaluateSteps(state: state, e: e, scratch: scratch) + debugStepSteps(state: state, e: e) + [
            debugSleepEdit(state: state, e: e, insert: false),
        ]
    }

    private static func debugSleepEdit(state: AppState, e: SelfTestEditor, insert: Bool) -> SelfTestStep {
        SelfTestStep(name: insert ? "debug sleep prep" : "debug sleep cleanup", wait: 0.6, run: {
            openRelative(state, "src/main.rs")
            e.focus()
            let range = insert ? NSRange(location: e.lineRange(sleepLine).location, length: 0) : e.lineRange(sleepLine)
            e.view?.setSelectedRange(range)
            e.view?.insertText(insert ? sleepCode + "\n" : "", replacementRange: range)
            state.saveAll()
        }, check: {
            e.expect((e.line(sleepLine) == sleepCode) == insert && state.activeBuffer?.isDirty == false, "line \(e.line(sleepLine))")
        })
    }

    private static func menuDebugWhileRunning(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "menu debug while running", wait: 0.5, until: { debugSettled(state) }, timeout: 180, run: {
            state.startRun(.plain(RunInvocation(argv: ["sleep", "30"], workingDir: state.workspaceRoot?.path)))
            scratch.performed = SelfTestMenu.perform("Debug › Debug")
        }, check: {
            e.expect(
                scratch.performed && debugStopped(state) && state.debug.stoppedLine == breakpointLine,
                "performed \(scratch.performed) state \(state.debug.state) line \(state.debug.stoppedLine) " + SelfTestRunScratch.status(state)
            )
        })
    }

    static func openRelative(_ state: AppState, _ relative: String) {
        if let url = state.workspaceRoot?.appendingPathComponent(relative) {
            state.openFile(url)
        }
    }

    static func debugSettled(_ state: AppState) -> Bool {
        debugStopped(state) || (!state.runOutput.isRunning && !state.debug.isActive)
    }

    static func debugStopped(_ state: AppState) -> Bool {
        state.debug.isStopped && state.debug.stoppedLine > 0
    }

    static func stoppedFile(_ state: AppState) -> String {
        (state.debug.stoppedPath as NSString?)?.lastPathComponent ?? "nil"
    }
}
