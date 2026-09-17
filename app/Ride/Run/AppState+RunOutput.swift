import AppKit

extension AppState {
    @discardableResult
    func runInOutput(_ invocation: RunInvocation) -> Int? {
        showRunOutput = true
        guard runOutput.isRunning else {
            return runOutput.start(invocation)
        }
        guard confirmStopAndRerun() else {
            return nil
        }
        return runOutput.stopAndStart(invocation)
    }

    func rerunOutput() {
        showRunOutput = true
        runOutput.rerun()
    }

    func toggleRunOutput() {
        showRunOutput.toggle()
    }

    func stopRun() {
        DebugChain.shared.cancel()
        BuildSession.shared.cancel()
        TestSession.shared.cancel()
        SingleFileChain.shared.cancel()
        runOutput.stop()
    }

    func runFinished(_ runId: Int, _ finish: RunFinish) {
        BuildSession.shared.finish(runId: runId, status: finish)
        TestSession.shared.finish(runId: runId, status: finish)
        continueSingleFile(runId, finish)
        continueDebug(runId, finish)
    }

    func stopRunOnWorkspaceChange() {
        runOutput.observeWorkspace($workspaceRoot)
    }

    func openConsoleLink(_ link: ConsoleLink) {
        let path = ConsoleLinks.absolutePath(link, root: workspaceRoot?.path)
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        openFile(url, at: .line(link.line, mark: false), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }

    private func confirmStopAndRerun() -> Bool {
        Confirm.ask("Stop and rerun?", message: "A process is already running.", ok: "Stop and Rerun")
    }
}

enum RunLineFilter {
    static func shown(runId: Int, line: String) -> String? {
        guard let passed = TestSession.shared.line(runId: runId, line) else {
            return nil
        }
        return BuildSession.shared.line(runId: runId, passed)
    }
}
