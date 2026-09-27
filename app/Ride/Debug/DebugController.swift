import Foundation

final class DebugController: ObservableObject {
    static let shared = DebugController()
    static let queue = DispatchQueue(label: "ride.debug.control", qos: .userInitiated)

    @Published private(set) var state = DebugState.idle
    @Published private(set) var stoppedPath: String?
    @Published private(set) var stoppedLine: UInt32 = 0
    @Published var breakpoints = Breakpoints()

    var onChange: (() -> Void)?
    var onOutput: ((String, String) -> Void)?
    var onStop: ((String?, UInt32) -> Void)?
    private(set) var sessionId: UInt64?
    private(set) var stopSequence = 0
    private var forwarder: DebugForwarder?
    private let breakpointSync = DebugBreakpointSync(queue: DebugController.queue)

    var isActive: Bool {
        switch state {
        case .launching, .running, .stopped:
            return true
        case .idle, .exited, .terminated:
            return false
        }
    }

    var isStopped: Bool {
        if case .stopped = state {
            return true
        }
        return false
    }

    var isRunning: Bool {
        if case .running = state {
            return true
        }
        return false
    }

    var stoppedThread: Int64? {
        guard case let .stopped(threadId, _) = state else {
            return nil
        }
        return threadId
    }

    @discardableResult
    func launch(_ request: DebugLaunch) -> Bool {
        guard let engine = RideEngineClient.shared.engine, !isActive else {
            return false
        }
        breakpointSync.cancel()
        let forwarder = DebugForwarder(controller: self)
        self.forwarder = forwarder
        publish(state: .launching, path: nil, line: 0)
        guard let id = try? engine.debugLaunch(
            launch: request,
            breakpoints: engineBreakpoints(),
            listener: forwarder
        ) else {
            end(state: .terminated)
            return false
        }
        sessionId = id
        return true
    }

    func send(_ command: DebugCommand) {
        guard let engine = RideEngineClient.shared.engine, let id = sessionId else {
            return
        }
        guard !DebugCommandEffect.disconnects(command) else {
            disconnect(engine: engine, id: id)
            return
        }
        guard (try? engine.debugCommand(sessionId: id, command: command)) != nil else {
            return
        }
        if DebugCommandEffect.resumes(command), isStopped {
            publish(state: .running, path: nil, line: 0)
        }
    }

    func sync(path: String) {
        guard let engine = RideEngineClient.shared.engine, let id = sessionId, isActive else {
            return
        }
        let marks = Self.engineBreakpoints(breakpoints.marks(path: path), path: path)
        breakpointSync.schedule(path: path, breakpoints: marks) { path, list in
            _ = try? engine.debugSetBreakpoints(sessionId: id, path: path, breakpoints: list)
        }
    }

    func engineBreakpoints() -> [Breakpoint] {
        breakpoints.paths.flatMap { path in
            Self.engineBreakpoints(breakpoints.marks(path: path), path: path)
        }
    }

    static func engineBreakpoints(_ marks: [BreakpointMark], path: String) -> [Breakpoint] {
        marks.map { mark in
            Breakpoint(
                path: path,
                line: mark.line,
                condition: mark.condition,
                hitCondition: mark.hitCondition,
                verified: mark.verified
            )
        }
    }

    func accepts(_ sender: DebugForwarder) -> Bool {
        sender === forwarder
    }

    func publish(state next: DebugState, path: String?, line: UInt32) {
        stopSequence += 1
        state = next
        locate(path: path, line: line)
    }

    func locate(path: String?, line: UInt32) {
        stoppedPath = path
        stoppedLine = line
        onStop?(path, line)
        onChange?()
    }

    func end(state next: DebugState) {
        sessionId = nil
        breakpointSync.cancel()
        breakpoints.unverifyAll()
        publish(state: next, path: nil, line: 0)
    }

    func changed() {
        onChange?()
    }

    private func disconnect(engine: Engine, id: UInt64) {
        forwarder = nil
        end(state: .terminated)
        Self.queue.async {
            try? engine.debugCommand(sessionId: id, command: .disconnect)
        }
    }
}
