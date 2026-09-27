import AppKit

extension AppState {
    @discardableResult
    func startRun(_ request: RunRequest, origin: RunRequest? = nil) -> Int? {
        saveAll()
        guard let runId = launchInOutput(request, origin: origin ?? request) else {
            return nil
        }
        beginSession(request, runId: runId)
        return runId
    }

    func rerunOutput() {
        guard let origin = runOutput.origin else {
            return
        }
        startRun(origin)
    }

    func toggleRunOutput() {
        showRunOutput.toggle()
    }

    func stopRun() {
        RunChain.shared.cancel()
        BuildSession.shared.cancel()
        TestSession.shared.cancel()
        runOutput.stop()
    }

    func runFinished(_ runId: Int, _ finish: RunFinish) {
        BuildSession.shared.finish(runId: runId, status: finish)
        TestSession.shared.finish(runId: runId, status: finish)
        switch RunChain.shared.take(runId: runId, status: finish) {
        case let .run(next):
            startRun(next, origin: runOutput.origin)
        case .debug:
            launchDebugger()
        case .none:
            break
        }
    }

    func stopRunOnWorkspaceChange() {
        runOutput.observeWorkspace($workspaceRoot)
    }

    func openConsoleLink(_ link: ConsoleLink) {
        let path = ConsoleLinks.absolutePath(link, root: runOutput.workingDir ?? workspaceRoot?.path)
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        openFile(url, at: .line(link.line, mark: false), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }

    private func launchInOutput(_ request: RunRequest, origin: RunRequest) -> Int? {
        showRunOutput = true
        guard runOutput.isRunning else {
            return runOutput.start(request, origin: origin)
        }
        guard confirmStopAndRerun() else {
            return nil
        }
        return runOutput.stopAndStart(request, origin: origin)
    }

    private func beginSession(_ request: RunRequest, runId: Int) {
        RunChain.shared.expect(request.then, after: runId)
        switch request.session {
        case .plain:
            BuildSession.shared.cancel()
            TestSession.shared.cancel()
        case let .build(kind, baseDir):
            TestSession.shared.cancel()
            BuildSession.shared.begin(runId: runId, kind: kind, baseDir: baseDir)
        case let .tests(framework):
            BuildSession.shared.cancel()
            beginTestRun(runId: runId, argv: request.invocation.argv, framework: framework)
        case let .singleFile(baseDir):
            TestSession.shared.cancel()
            BuildSession.shared.begin(runId: runId, kind: .none, baseDir: baseDir)
        }
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
