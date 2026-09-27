import AppKit

extension AppState {
    var runTarget: RunTarget? {
        projectModel.runTarget
    }

    var runConfig: RunConfig {
        runConfig(for: runTarget)
    }

    func runConfig(for target: RunTarget?) -> RunConfig {
        RunConfig.config(
            for: target?.name ?? "",
            in: runConfigs,
            workingDir: target?.workingDir ?? activeProjectRoot?.path
        )
    }

    func runPlan(_ action: RunAction) -> RunPlan? {
        runPlan(action, target: runTarget)
    }

    func runPlan(_ action: RunAction, target: RunTarget?) -> RunPlan? {
        RunPlanner.plan(
            action,
            target: target,
            targets: projectModel.runTargets,
            config: runConfig(for: target),
            kind: projectModel.runKind,
            profile: projectModel.profile
        )
    }

    func canRun(_ action: RunAction) -> Bool {
        runPlan(action) != nil
    }

    func runAction(_ action: RunAction) {
        guard let request = runRequest(action) else {
            showNotice("Nothing to \(action.rawValue) for this project")
            return
        }
        startRun(request)
    }

    func runRequest(_ action: RunAction, target: RunTarget? = nil) -> RunRequest? {
        guard let plan = runPlan(action, target: target ?? runTarget) else {
            return nil
        }
        return RunRequests.request(
            action,
            plan: plan,
            kind: projectModel.runKind,
            root: activeProjectRoot?.path ?? ""
        )
    }

    func editRunConfig() {
        guard runTarget != nil else {
            return
        }
        runConfigEditor.begin(runConfig, kind: projectModel.runKind)
        showRunConfigSheet = true
    }

    func saveRunConfig() {
        runConfigs = RunConfig.merged(runConfigEditor.config, into: runConfigs)
        showRunConfigSheet = false
    }

    func cancelRunConfig() {
        showRunConfigSheet = false
    }

    func selectTarget(_ row: TargetRow?) {
        projectModel.select(row)
    }
}
