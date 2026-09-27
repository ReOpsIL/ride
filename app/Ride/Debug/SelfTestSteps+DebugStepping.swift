import AppKit

extension SelfTestSteps {
    static let continueLine: UInt32 = 12

    static func debugStepSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            debugMenuStep("Step Into", state: state, e: e) { stoppedFile(state) == "util.rs" },
            debugMenuStep("Step Out", state: state, e: e) { stoppedFile(state) == "main.rs" && state.debug.stoppedLine >= breakpointLine },
            debugMenuStep("Step Over", state: state, e: e) { stoppedFile(state) == "main.rs" && state.debug.stoppedLine > breakpointLine },
            menuDebugContinue(state: state, e: e),
            menuDebugPause(state: state, e: e),
            menuDebugStop(state: state, e: e, name: "menu debug stop"),
            rerunDebugSession(state: state, e: e),
            menuDebugStop(state: state, e: e, name: "menu debug stop after rerun"),
        ]
    }

    private static func debugMenuStep(_ title: String, state: AppState, e: SelfTestEditor, landed: @escaping () -> Bool) -> SelfTestStep {
        menuStep("menu debug \(title.lowercased())", "Debug › \(title)", timeout: 30, done: { debugStopped(state) && landed() }) { pressed in
            e.expect(
                pressed && debugStopped(state) && landed(),
                "pressed \(pressed) at \(stoppedFile(state)):\(state.debug.stoppedLine)"
            )
        }
    }

    private static func menuDebugContinue(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        menuStep("menu debug continue", "Debug › Continue", timeout: 30, prepare: {
            if let path = debugPath(state) {
                state.toggleBreakpoint(path: path, line: continueLine)
            }
        }, done: { debugStopped(state) && state.debug.stoppedLine == continueLine }) { pressed in
            let line = state.debug.stoppedLine
            if let path = debugPath(state) {
                state.toggleBreakpoint(path: path, line: continueLine)
            }
            return e.expect(pressed && line == continueLine && marks(state) == [breakpointLine], "line \(line) marks \(marks(state))")
        }
    }

    private static func menuDebugPause(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let resume = SelfTestMenuPress("Debug › Continue")
        let pause = SelfTestMenuPress("Debug › Pause")
        return SelfTestStep(name: "menu debug pause", wait: 0.5, until: {
            guard resume.pressWhenEnabled() else {
                return false
            }
            if !pause.pressed, state.debug.isRunning {
                _ = pause.pressWhenEnabled()
            }
            return pause.pressed && debugStopped(state)
        }, timeout: 30, run: {
            resume.reset()
            pause.reset()
        }, check: {
            e.expect(
                resume.pressed && pause.pressed && debugStopped(state) && !["breakpoint", "step"].contains(pausedReason(state)),
                "resumed \(resume.pressed) paused \(pause.pressed) reason \(pausedReason(state)) line \(state.debug.stoppedLine)"
            )
        })
    }

    private static func pausedReason(_ state: AppState) -> String {
        guard case let .stopped(_, reason) = state.debug.state else {
            return "\(state.debug.state)"
        }
        return reason
    }

    private static func menuDebugStop(state: AppState, e: SelfTestEditor, name: String) -> SelfTestStep {
        menuStep(name, "Debug › Stop", timeout: 30, done: { !state.debug.isActive }) { pressed in
            e.expect(pressed && !state.debug.isActive, "pressed \(pressed) state \(state.debug.state)")
        }
    }

    private static func rerunDebugSession(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "rerun after debug relaunches the debugger", wait: 0.5, until: { debugSettled(state) }, timeout: 240, run: {
            state.rerunOutput()
        }, check: {
            e.expect(
                debugStopped(state) && state.debug.stoppedLine == breakpointLine,
                "state \(state.debug.state) line \(state.debug.stoppedLine) " + SelfTestRunScratch.status(state)
            )
        })
    }
}
