import AppKit

extension AppState {
    func runInOutput(_ invocation: RunInvocation) {
        showRunOutput = true
        guard runOutput.isRunning else {
            runOutput.start(invocation)
            return
        }
        guard confirmStopAndRerun() else {
            return
        }
        runOutput.stopAndStart(invocation)
    }

    func rerunOutput() {
        showRunOutput = true
        runOutput.rerun()
    }

    func stopRun() {
        runOutput.stop()
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
        let alert = NSAlert()
        alert.messageText = "Stop and rerun?"
        alert.informativeText = "A process is already running."
        alert.addButton(withTitle: "Stop and Rerun")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
