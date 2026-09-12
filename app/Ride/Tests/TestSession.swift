import Foundation

final class TestSession {
    static let shared = TestSession()
    static let liveLimit = 65536

    private var state = BuildSessionState()
    private var framework = TestFramework.cargo
    private var text = ""

    func begin(runId: Int, framework: TestFramework, command: String?) {
        self.framework = framework
        text = ""
        state.begin(runId: runId)
        TestRunStore.shared.begin(command: command)
    }

    func cancel() {
        state.cancel()
    }

    func line(_ line: String) {
        guard state.isActive else {
            return
        }
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

    static func framework(for kind: RunProjectKind) -> TestFramework? {
        switch kind {
        case .cargo:
            return .cargo
        case .cmake:
            return .cTest
        case .make, .compileDb, .none:
            return nil
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
