import AppKit

extension SelfTestSteps {
    static func targetSteps(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> [SelfTestStep] {
        [mainMarkerRunsOwner(state: state, e: e), targetRowPersists(state: state, e: e), profileRelease(state: state, e: e, scratch: scratch), profileRestore(state: state, e: e, scratch: scratch)]
    }

    private static func mainMarkerRunsOwner(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "gutter main marker runs its binary", wait: 0.5, until: { SelfTestRunScratch.finished(state) }, timeout: 180, run: {
            let store = state.projectModel
            store.select(store.rows.first { $0.kind == .test })
            state.runTestMarker(TestMarkerRow(name: "main", framework: nil), path: debugPath(state))
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.text.contains("ride: 1") && state.projectModel.selected?.kind == .test,
                "selected \(state.projectModel.selected?.id ?? "nil") " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func targetRowPersists(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "targets row click persists", wait: 0.4, run: {
            let store = state.projectModel
            store.select(store.rows.first { $0.kind == .test })
            store.select(store.rows.first { $0.kind == .bin })
        }, check: {
            let bin = state.projectModel.rows.first { $0.kind == .bin }
            return e.expect(
                bin != nil && state.captureWorkspace().selectedTarget == bin?.name && state.menu.selectedTarget == bin?.name
                    && state.projectModel.onChoice != nil,
                "saved \(state.captureWorkspace().selectedTarget ?? "nil") menu \(state.menu.selectedTarget ?? "nil")"
            )
        })
    }

    private static func profileRelease(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "targets profile release builds release", wait: 0.5, until: { SelfTestRunScratch.finished(state) }, timeout: 240, run: {
            scratch.profile = state.projectModel.profile
            state.projectModel.choose(profile: RunVariant.release)
            scratch.performed = SelfTestMenu.perform("Run › Build")
        }, check: {
            let binary = cargoBinary(state)
            return e.expect(
                scratch.performed && state.runOutput.status == "exit 0" && state.runOutput.command?.contains("--release") == true
                    && FileManager.default.isExecutableFile(atPath: binary) && state.captureWorkspace().profile == RunVariant.release,
                "binary \(binary) saved \(state.captureWorkspace().profile ?? "nil") " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func profileRestore(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "targets profile restore", wait: 0.3, run: {
            guard let data = try? JSONEncoder().encode(state.captureWorkspace()),
                  var loaded = WorkspaceState.decode(data)
            else {
                return
            }
            loaded.profile = scratch.profile
            state.restoreWorkspace(loaded)
        }, check: {
            e.expect(
                state.projectModel.profile == scratch.profile && state.runPlan(.build)?.argv.contains("--release") == false
                    && cargoBinary(state).contains("/debug/"),
                "profile \(state.projectModel.profile) binary \(cargoBinary(state))"
            )
        })
    }

    private static func cargoBinary(_ state: AppState) -> String {
        guard let target = state.runTarget else {
            return ""
        }
        let variant = RunVariant(kind: .cargo, profile: state.projectModel.profile, sanitizers: [])
        return DebugProgram.cargoBinary(target: target, variant: variant)
    }
}
