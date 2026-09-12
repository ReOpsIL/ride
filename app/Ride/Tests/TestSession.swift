import Foundation

final class TestSession {
    static let shared = TestSession()
    static let liveLimit = 65536

    private var state = BuildSessionState()
    private var framework = TestFramework.cargo
    private var text = ""

    func begin(runId: Int, framework: TestMarkerFramework, command: String?) {
        self.framework = Self.engineFramework(framework)
        text = ""
        state.begin(runId: runId)
        TestRunStore.shared.begin(command: command, framework: framework)
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
            accept(line)
            return line
        }
    }

    private func accept(_ line: String) {
        text += line + "\n"
        guard text.utf8.count < Self.liveLimit else {
            return
        }
        publish()
    }

    func finish(runId: Int, status: RunFinish) {
        guard state.accepts(runId: runId) else {
            return
        }
        let outcome = state.finish(runId: runId, status: status)
        publish()
        TestRunStore.shared.finish(label(outcome, status: status))
    }

    static func framework(for kind: RunProjectKind) -> TestMarkerFramework? {
        switch kind {
        case .cargo:
            return .cargo
        case .cmake:
            return .ctest
        case .make, .compileDb, .none:
            return nil
        }
    }

    static func engineFramework(_ framework: TestMarkerFramework) -> TestFramework {
        switch framework {
        case .cargo:
            return .cargo
        case .googleTest:
            return .googleTest
        case .catch2:
            return .catch2
        case .ctest:
            return .cTest
        }
    }

    private func publish() {
        guard let engine = RideEngineClient.shared.engine else {
            return
        }
        TestRunStore.shared.apply(engine.parseTestOutput(framework: framework, text: text))
    }

    private func label(_ outcome: BuildFinish, status: RunFinish) -> String? {
        guard outcome == .publish else {
            return "stopped"
        }
        return status.succeeded ? "passed" : "failed"
    }
}
