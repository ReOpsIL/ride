import AppKit

extension SelfTestSteps {
    static func runMenuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let scratch = SelfTestRunScratch()
        return [
            menuRunBuild(state: state, e: e),
            menuRunRun(state: state, e: e),
            menuRunTests(state: state, e: e),
            menuRunStop(state: state, e: e),
            menuRunFile(state: state, e: e),
            rerunRunFile(state: state, e: e, scratch: scratch),
        ] + runConfigSteps(state: state, e: e, scratch: scratch)
    }

    private static func menuRunBuild(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        menuStep("menu run build", "Run › Build", timeout: 240, done: { SelfTestRunScratch.finished(state) }) { pressed in
            e.expect(
                pressed && state.runOutput.status == "exit 0" && state.runOutput.text.contains("Finished"),
                "pressed \(pressed) " + SelfTestRunScratch.status(state)
            )
        }
    }

    private static func menuRunRun(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        menuStep("menu run run", "Run › Run", timeout: 180, done: { SelfTestRunScratch.finished(state) }) { pressed in
            e.expect(
                pressed && state.runOutput.status == "exit 0" && state.runOutput.text.contains("ride: 1"),
                "pressed \(pressed) " + SelfTestRunScratch.status(state)
            )
        }
    }

    private static func menuRunTests(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        menuStep("menu run tests", "Run › Run Tests", timeout: 240, done: { SelfTestRunScratch.finished(state) }) { pressed in
            let tree = TestRunStore.shared.tree
            return e.expect(
                pressed && state.showTests && state.menu.showTests && tree.passed == 1 && tree.failed == 0,
                "pressed \(pressed) passed \(tree.passed) failed \(tree.failed) " + SelfTestRunScratch.status(state)
            )
        }
    }

    private static func menuRunStop(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        menuStep("menu run stop", "Run › Stop", timeout: 30, prepare: {
            state.startRun(.plain(RunInvocation(argv: ["sleep", "30"], workingDir: state.workspaceRoot?.path)))
        }, done: { SelfTestRunScratch.finished(state) }) { pressed in
            e.expect(
                pressed && state.runOutput.status == "stopped" && !state.menu.isRunning,
                "pressed \(pressed) " + SelfTestRunScratch.status(state)
            )
        }
    }

    private static func menuRunFile(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        menuStep("menu run file", "Run › Run File", timeout: 120, prepare: { e.focus() }, done: { ranSingleFile(state) }) { pressed in
            e.expect(
                pressed && ranSingleFile(state) && state.runOutput.status == "exit 0",
                "pressed \(pressed) " + SelfTestRunScratch.status(state)
            )
        }
    }

    private static func rerunRunFile(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "rerun after run file recompiles", wait: 0.5, until: { ranSingleFile(state) }, timeout: 120, run: {
            state.rerunOutput()
            scratch.step = state.runOutput.lastRequest
        }, check: {
            let compiled: Bool
            if case .singleFile = scratch.step?.session {
                compiled = true
            } else {
                compiled = false
            }
            return e.expect(
                compiled && ranSingleFile(state) && state.runOutput.status == "exit 0",
                "first step \(String(describing: scratch.step?.session)) " + SelfTestRunScratch.status(state)
            )
        })
    }

    static func ranSingleFile(_ state: AppState) -> Bool {
        guard SelfTestRunScratch.finished(state), state.runOutput.lastRequest?.session == .plain else {
            return false
        }
        return state.runOutput.text.contains("events: 2")
    }
}
