import Foundation

final class DebugBreakpointSync {
    static let delay = 0.15

    private let queue: DispatchQueue
    private var pending: [String: [Breakpoint]] = [:]
    private var send: ((String, [Breakpoint]) -> Void)?
    private var flushWork: DispatchWorkItem?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func schedule(path: String, breakpoints: [Breakpoint], send: @escaping (String, [Breakpoint]) -> Void) {
        pending[path] = breakpoints
        self.send = send
        guard flushWork == nil else {
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.flush()
        }
        flushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    func cancel() {
        flushWork?.cancel()
        flushWork = nil
        pending = [:]
        send = nil
    }

    private func flush() {
        flushWork = nil
        let batch = pending
        pending = [:]
        guard let send else {
            return
        }
        queue.async {
            for (path, list) in batch.sorted(by: { $0.key < $1.key }) {
                send(path, list)
            }
        }
    }
}
