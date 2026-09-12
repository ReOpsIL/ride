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
        publish(state: .stopped(threadId: threadId, reason: reason), path: nil, line: 0)
        locateTopFrame(threadId: threadId)
    }

    private func locateTopFrame(threadId: Int64) {
        guard let engine = RideEngineClient.shared.engine, let id = sessionId else {
            return
        }
        let sequence = stopSequence
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let frames = (try? engine.debugStack(sessionId: id, threadId: threadId)) ?? []
            let frame = frames.first { $0.path != nil } ?? frames.first
            DispatchQueue.main.async {
                guard let self, self.stopSequence == sequence, self.isStopped else {
                    return
                }
                self.locate(path: frame?.path, line: frame?.line ?? 0)
            }
        }
    }
}
