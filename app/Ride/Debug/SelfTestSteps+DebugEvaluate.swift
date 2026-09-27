import AppKit

extension SelfTestSteps {
    static func debugEvaluateSteps(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> [SelfTestStep] {
        [menuDebugEvaluate(state: state, e: e, scratch: scratch), evaluateWatchAndClose(state: state, e: e)]
    }

    private static func menuDebugEvaluate(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        let evaluation = DebugEvaluation.shared
        return SelfTestStep(name: "menu debug evaluate", wait: 0.5, until: { evaluation.result != "evaluating…" }, timeout: 30, run: {
            scratch.performed = SelfTestMenu.perform("Debug › Evaluate Expression…")
            evaluation.expression = " counter "
            evaluation.evaluate(in: state.debugPanel)
        }, check: {
            e.expect(
                scratch.performed && state.debugPanel.showEvaluate && state.debugPanel.visible && state.menu.showDebugPanel
                    && !evaluation.failed && !evaluation.result.isEmpty,
                "performed \(scratch.performed) sheet \(state.debugPanel.showEvaluate) result '\(evaluation.result)' failed \(evaluation.failed)"
            )
        })
    }

    private static func evaluateWatchAndClose(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        let evaluation = DebugEvaluation.shared
        return SelfTestStep(name: "evaluate watch remove close", wait: 0.5, run: {
            evaluation.watch(in: state.debugPanel)
        }, check: {
            let watched = state.debugPanel.expressions
            state.debugPanel.removeWatch(id: "counter")
            evaluation.close(state.debugPanel)
            evaluation.expression = ""
            return e.expect(
                watched == ["counter"] && state.debugPanel.expressions.isEmpty && !state.debugPanel.showEvaluate,
                "watched \(watched) left \(state.debugPanel.expressions) sheet \(state.debugPanel.showEvaluate)"
            )
        })
    }
}
