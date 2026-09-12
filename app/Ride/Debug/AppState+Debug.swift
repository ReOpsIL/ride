import AppKit

extension AppState {
    var debug: DebugController {
        DebugController.shared
    }

    var canDebug: Bool {
        debugLaunch() != nil
    }

    func observeDebug() {
        debug.onChange = { [weak self] in
            self?.debugChanged()
        }
        debug.onOutput = { [weak self] _, text in
            self?.appendDebugOutput(text)
        }
    }

    func startDebug() {
        guard !debug.isActive else {
            return
        }
        guard let launch = debugLaunch() else {
            showNotice("Nothing to debug for this project")
            return
        }
        DebugChain.shared.cancel()
        showRunOutput = true
        guard canRun(.build) else {
            debug.launch(launch)
            return
        }
        runAction(.build)
        guard runOutput.isRunning else {
            return
        }
        DebugChain.shared.expect(launch, after: runOutput.runId)
    }

    func continueDebug(_ runId: Int, _ finish: RunFinish) {
        guard let launch = DebugChain.shared.take(runId: runId, status: finish) else {
            return
        }
        debug.launch(launch)
    }

    func debugCommand(_ command: DebugCommand) {
        debug.send(command)
    }

    func stopDebug() {
        DebugChain.shared.cancel()
        debug.send(.disconnect)
    }

    private func appendDebugOutput(_ text: String) {
        let body = text.hasSuffix("\n") ? String(text.dropLast()) : text
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            runOutput.append(String(line))
        }
    }

    private func debugLaunch() -> DebugLaunch? {
        guard let target = runTarget, let plan = runPlan(.run) else {
            return nil
        }
        guard let resolved = DebugProgram.resolve(
            plan: plan,
            kind: projectModel.runKind,
            targetName: target.name,
            workingDir: target.workingDir,
            profile: projectModel.profile
        ) else {
            return nil
        }
        return DebugLaunch(
            program: resolved.program,
            args: resolved.args,
            cwd: plan.cwd ?? nonEmpty(target.workingDir) ?? workspaceRoot?.path,
            env: plan.env,
            stopOnEntry: false
        )
    }

    private func nonEmpty(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }
}
