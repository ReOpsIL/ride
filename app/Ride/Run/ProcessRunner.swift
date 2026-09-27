import Foundation

final class ProcessRunner {
    private var session: ProcessSession?
    private let queue = DispatchQueue(label: "ride.run.output")

    var isRunning: Bool {
        session != nil
    }

    func start(
        _ invocation: RunInvocation,
        runId: Int,
        onLine: @escaping (Int, String) -> Void,
        onFinish: @escaping (RunFinish) -> Void
    ) {
        guard !isRunning, let tool = invocation.argv.first else {
            report(.failed("no command"), onFinish: onFinish)
            return
        }
        guard let executable = ProcessLookup.url(for: tool, workingDir: invocation.workingDir) else {
            report(.failed("command not found: \(tool)"), onFinish: onFinish)
            return
        }
        do {
            let spawned = try ProcessSpawn.launch(
                executable: executable.path,
                arguments: Array(invocation.argv.dropFirst()),
                environment: Self.environment(invocation),
                workingDir: invocation.workingDir
            )
            begin(ProcessSession(spawned, queue: queue), runId: runId, onLine: onLine, onFinish: onFinish)
        } catch {
            report(.failed(error.localizedDescription), onFinish: onFinish)
        }
    }

    func stop() {
        session?.stop()
    }

    private func begin(
        _ session: ProcessSession,
        runId: Int,
        onLine: @escaping (Int, String) -> Void,
        onFinish: @escaping (RunFinish) -> Void
    ) {
        session.onLines = { lines in
            DispatchQueue.main.async {
                lines.forEach { onLine(runId, $0) }
            }
        }
        session.onFinish = { [weak self, weak session] status in
            DispatchQueue.main.async {
                if let self, self.session === session {
                    self.session = nil
                }
                onFinish(status)
            }
        }
        self.session = session
        session.start()
    }

    private func report(_ finish: RunFinish, onFinish: @escaping (RunFinish) -> Void) {
        DispatchQueue.main.async {
            onFinish(finish)
        }
    }

    private static func environment(_ invocation: RunInvocation) -> [String: String] {
        ProcessInfo.processInfo.environment
            .merging(["PATH": ShellPath.value]) { _, new in new }
            .merging(invocation.env) { _, new in new }
    }
}
