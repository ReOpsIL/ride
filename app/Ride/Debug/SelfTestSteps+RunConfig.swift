import AppKit

extension SelfTestSteps {
    static let configArg = "ride-arg"

    static func runConfigSteps(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> [SelfTestStep] {
        [
            menuEditConfigurations(state: state, e: e, scratch: scratch),
            runConfigEnvRows(state: state, e: e),
            runConfigCancel(state: state, e: e),
            runConfigSave(state: state, e: e, scratch: scratch),
            runConfigRestore(state: state, e: e, scratch: scratch),
        ]
    }

    private static func menuEditConfigurations(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "menu edit configurations", wait: 0.6, run: {
            scratch.configs = state.runConfigs
            scratch.performed = SelfTestMenu.perform("Run › Edit Configurations…")
        }, check: {
            let editor = state.runConfigEditor
            return e.expect(
                scratch.performed && state.showRunConfigSheet && editor.target == state.runTarget?.name
                    && editor.sanitizers == [.address, .thread] && editor.draft.args.isEmpty,
                "performed \(scratch.performed) shown \(state.showRunConfigSheet) target \(editor.target) sanitizers \(editor.sanitizers)"
            )
        })
    }

    private static func runConfigEnvRows(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run config env add remove", wait: 0.3, run: {
            let editor = state.runConfigEditor
            editor.addEnvRow()
            editor.addEnvRow()
            if let first = editor.draft.env.first?.id {
                editor.removeEnvRow(id: first)
            }
        }, check: {
            let rows = state.runConfigEditor.draft.env
            return e.expect(rows.count == 1 && rows.first?.key.isEmpty == true, "rows \(rows.map(\.key))")
        })
    }

    private static func runConfigCancel(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "run config cancel", wait: 0.5, run: {
            state.runConfigEditor.draft.args = "ride-cancelled"
            state.cancelRunConfig()
        }, check: {
            e.expect(
                !state.showRunConfigSheet && state.runConfig.args.isEmpty,
                "shown \(state.showRunConfigSheet) args \(state.runConfig.args)"
            )
        })
    }

    private static func runConfigSave(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "run config save", wait: 0.5, until: { SelfTestRunScratch.finished(state) }, timeout: 180, run: {
            SelfTestMenu.perform("Run › Edit Configurations…")
            let editor = state.runConfigEditor
            editor.draft.args = configArg
            editor.addEnvRow()
            editor.draft.env[0].key = "RIDE_ENV"
            editor.draft.env[0].value = "1"
            editor.set(.address, on: true)
            editor.set(.thread, on: true)
            scratch.performed = editor.draft.sanitizers == [.thread]
            editor.set(.thread, on: false)
            state.saveRunConfig()
            SelfTestMenu.perform("Run › Run")
        }, check: {
            let run = state.runPlan(.run)?.argv ?? []
            let build = state.runPlan(.build)?.argv ?? []
            return e.expect(
                scratch.performed && !state.showRunConfigSheet && run.suffix(2) == ["--", configArg] && !build.contains(configArg)
                    && state.runPlan(.run)?.env["RIDE_ENV"] == "1" && state.runOutput.status == "exit 0"
                    && state.runOutput.command?.hasSuffix("-- \(configArg)") == true,
                "exclusive \(scratch.performed) run \(run) build \(build) " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func runConfigRestore(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "run config restore", wait: 0.3, run: {
            state.runConfigs = scratch.configs
        }, check: {
            e.expect(state.runConfig.args.isEmpty && state.runConfig.env.isEmpty, "config \(state.runConfig)")
        })
    }
}
