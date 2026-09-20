import AppKit

extension SelfTestSteps {
    static func rustRun(state: AppState, e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            projectTargets(state: state, e: e),
            buildStopped(state: state, e: e),
            buildStopAndRerun(state: state, e: e, scratch: scratch),
            buildTarget(state: state, e: e),
            runTarget(state: state, e: e),
            runTests(state: state, e: e),
            testStopAndRerun(state: state, e: e, scratch: scratch),
            gutterRunMarkers(state: state, e: e),
            buildDiagnostic(state: state, e: e, scratch: scratch),
            buildDiagnosticCleared(state: state, e: e, scratch: scratch),
        ] + debugSteps(state: state, e: e)
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
}
