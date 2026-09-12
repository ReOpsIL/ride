import Foundation

final class BuildSession {
    static let shared = BuildSession()

    private var kind = RunProjectKind.none
    private var baseDir = ""
    private var cargo: [Diagnostic] = []
    private var text = ""
    private var state = BuildSessionState()

    func begin(runId: Int, kind: RunProjectKind, baseDir: String) {
        self.kind = kind
        self.baseDir = baseDir
        cargo = []
        text = ""
        state.begin(runId: runId)
    }

    func cancel() {
        state.cancel()
    }

    func line(runId: Int, _ line: String) -> String? {
        switch state.line(runId: runId) {
        case .drop:
            return nil
        case .passThrough:
            return line
        case .accept:
            return accepted(line)
        }
    }

    private func accepted(_ line: String) -> String? {
        guard kind == .cargo else {
            text += line + "\n"
            return line
        }
        guard BuildParse.isMessage(line) else {
            return line
        }
        cargo += RideEngineClient.shared.engine?.parseCargoLine(line: line) ?? []
        return BuildParse.rendered(line)
    }

    func finish(runId: Int, status: RunFinish) {
        guard state.finish(runId: runId, status: status) == .publish else {
            return
        }
        CheckService.shared.replaceBuild(diagnostics())
    }

    private func diagnostics() -> [Diagnostic] {
        guard kind != .cargo else {
            return cargo
        }
        guard let engine = RideEngineClient.shared.engine else {
            return []
        }
        return engine.parseClangOutput(text: text, baseDir: baseDir)
    }
}
