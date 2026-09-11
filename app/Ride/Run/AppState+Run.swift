import AppKit

extension AppState {
    var runTarget: RunTarget? {
        projectModel.runTarget
    }

    var runConfig: RunConfig {
        let target = runTarget
        return RunConfig.config(
            for: target?.name ?? "",
            in: runConfigs,
            workingDir: target?.workingDir ?? workspaceRoot?.path
        )
    }

    func runPlan(_ action: RunAction) -> RunPlan? {
        RunPlanner.plan(
            action,
            target: runTarget,
            targets: projectModel.runTargets,
            config: runConfig,
            kind: projectModel.runKind,
            profile: projectModel.profile
        )
    }

    func canRun(_ action: RunAction) -> Bool {
        runPlan(action) != nil
    }

    func runAction(_ action: RunAction) {
        guard let plan = runPlan(action) else {
            showNotice("Nothing to \(action.rawValue) for this project")
            return
        }
        runInOutput(RunInvocation(argv: plan.argv, workingDir: plan.cwd, env: plan.env))
    }

    func editRunConfig() {
        guard runTarget != nil else {
            return
        }
        showRunConfigSheet = true
    }

    func saveRunConfig(_ config: RunConfig) {
        runConfigs = RunConfig.merged(config, into: runConfigs)
    }

    func selectTarget(_ row: TargetRow?) {
        projectModel.select(row)
        scheduleWorkspaceSave()
    }
}
