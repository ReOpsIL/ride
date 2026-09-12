import AppKit

extension AppState {
    var singleFilePath: String? {
        activeBuffer?.fileURL?.standardizedFileURL.path
    }

    var canRunFile: Bool {
        SingleFileRun.canRun(path: singleFilePath)
    }

    var canRecompileFile: Bool {
        singleFilePath != nil
    }

    func runFile() {
        guard let path = singleFilePath, let engine = RideEngineClient.shared.engine else {
            return
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let outDir = base.appendingPathComponent("Ride/" + SingleFileRun.outputName(for: path))
        let directory = (path as NSString).deletingLastPathComponent
        guard let single = try? engine.singleFileCommand(path: path, outDir: outDir.path) else {
            showNotice("No single-file runner for this file")
            return
        }
        startSingleFile(
            RunInvocation(argv: single.compile, workingDir: directory),
            baseDir: directory,
            then: RunInvocation(argv: single.run, workingDir: directory)
        )
    }

    func recompileFile() {
        guard let path = singleFilePath, let engine = RideEngineClient.shared.engine else {
            return
        }
        guard let command = engine.recompileCommand(path: path) else {
            showNotice("No compile database entry for this file")
            return
        }
        startSingleFile(
            RunInvocation(argv: command.argv, workingDir: command.directory),
            baseDir: command.directory,
            then: nil
        )
    }

    func continueSingleFile(_ runId: Int, _ finish: RunFinish) {
        guard let next = SingleFileChain.shared.take(runId: runId, status: finish) else {
            return
        }
        runInOutput(next)
    }

    private func startSingleFile(_ invocation: RunInvocation, baseDir: String, then next: RunInvocation?) {
        guard let runId = runInOutput(invocation) else {
            return
        }
        BuildSession.shared.begin(runId: runId, kind: .none, baseDir: baseDir)
        SingleFileChain.shared.expect(next, after: runId)
    }
}
