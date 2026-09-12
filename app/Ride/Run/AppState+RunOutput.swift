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
        BuildSession.shared.cancel()
        TestSession.shared.cancel()
        SingleFileChain.shared.cancel()
        runOutput.stop()
    }

    func runFinished(_ runId: Int, _ finish: RunFinish) {
        BuildSession.shared.finish(runId: runId, status: finish)
        TestSession.shared.finish(runId: runId, status: finish)
        continueSingleFile(runId, finish)
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
        openFile(url, readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
        DispatchQueue.main.async {
            EditorPanes.shared.focused?.jump(toLine: link.line)
        }
    }

    private func confirmStopAndRerun() -> Bool {
        guard !DemoLaunch.isDemo else {
            return true
        }
        let alert = NSAlert()
        alert.messageText = "Stop and rerun?"
        alert.informativeText = "A process is already running."
        alert.addButton(withTitle: "Stop and Rerun")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
