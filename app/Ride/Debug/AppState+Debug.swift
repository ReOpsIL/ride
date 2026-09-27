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
        debug.onStop = { [weak self] path, line in
            self?.showDebugLocation(path: path, line: line)
        }
        debug.onOutput = { [weak self] _, text in
            self?.appendDebugOutput(text)
        }
        observeDebugPanel()
    }

    func startDebug() {
        guard !debug.isActive else {
            return
        }
        guard debugLaunch() != nil else {
            showNotice("Nothing to debug for this project")
            return
        }
        showRunOutput = true
        guard let build = runRequest(.build) else {
            launchDebugger()
            return
        }
        startRun(build.followed(by: .debug))
    }

    func launchDebugger() {
        guard !debug.isActive, let launch = debugLaunch() else {
            return
        }
        debug.launch(launch)
    }

    func debugCommand(_ command: DebugCommand) {
        debug.send(command)
    }

    func stopDebug() {
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
        let variant = RunVariant(
            kind: projectModel.runKind,
            profile: projectModel.profile,
            sanitizers: runConfig.activeSanitizers(for: projectModel.runKind)
        )
        guard let resolved = DebugProgram.resolve(plan: plan, target: target, variant: variant) else {
            return nil
        }
        return DebugLaunch(
            program: resolved.program,
            args: resolved.args,
            cwd: plan.cwd ?? DebugProgram.emptyToNil(target.workingDir) ?? activeProjectRoot?.path,
            env: plan.env,
            stopOnEntry: false,
            exceptionFilters: DebugFilters.shared.enabledIds
        )
    }
}
