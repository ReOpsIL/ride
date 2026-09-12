import Foundation

extension DebugController {
    func handle(_ event: DebugEvent) {
        switch event {
        case .launching:
            publish(state: .launching, path: nil, line: 0)
        case .running:
            publish(state: .running, path: nil, line: 0)
        case let .stopped(threadId, reason, _, _):
            stopped(threadId: threadId, reason: reason)
        case .continued:
            publish(state: .running, path: nil, line: 0)
        case let .breakpoints(path, list):
            breakpoints.verify(path: path, verified: Set(list.filter(\.verified).map(\.line)))
            changed()
        case let .exited(code):
            sessionId = nil
            publish(state: .exited(code: code), path: nil, line: 0)
        case .terminated:
            sessionId = nil
            publish(state: .terminated, path: nil, line: 0)
        case let .failed(message):
            sessionId = nil
            onOutput?("stderr", message + "\n")
            publish(state: .terminated, path: nil, line: 0)
        }
    }

    private func stopped(threadId: Int64, reason: String) {
        let frame = topFrame(threadId: threadId)
        publish(
            state: .stopped(threadId: threadId, reason: reason),
            path: frame?.path,
            line: frame?.line ?? 0
        )
    }

    private func topFrame(threadId: Int64) -> StackFrame? {
        guard let engine = RideEngineClient.shared.engine, let id = sessionId else {
            return nil
        }
        let frames = (try? engine.debugStack(sessionId: id, threadId: threadId)) ?? []
        return frames.first { $0.path != nil } ?? frames.first
    }
}
