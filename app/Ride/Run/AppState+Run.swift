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
        let kind = projectModel.runKind
        let building = action == .build
        let argv = building && kind == .cargo ? BuildParse.cargoArgv(plan.argv) : plan.argv
        guard let runId = runInOutput(RunInvocation(argv: argv, workingDir: plan.cwd, env: plan.env)) else {
            return
        }
        SingleFileChain.shared.cancel()
        guard building else {
            BuildSession.shared.cancel()
            return
        }
        BuildSession.shared.begin(
            runId: runId,
            kind: kind,
            baseDir: plan.cwd ?? workspaceRoot?.path ?? ""
        )
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
