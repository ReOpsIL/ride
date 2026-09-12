import Combine
import Foundation

final class RunOutput: ObservableObject {
    static let maxLines = 5000

    @Published private(set) var buffer = RunOutputBuffer(maxLines: RunOutput.maxLines)
    @Published private(set) var isRunning = false
    @Published private(set) var status: String?
    @Published private(set) var command: String?

    var onChange: (() -> Void)?
    var lineFilter: ((Int, String) -> String?)?
    var onFinish: ((Int, RunFinish) -> Void)?
    private let runner = ProcessRunner()
    private var last: RunInvocation?
    private var queued: (id: Int, invocation: RunInvocation)?
    private var workspaceSink: AnyCancellable?
    private var nextId = 0
    private var stopping = false
    private(set) var runId = 0

    var lines: [String] {
        buffer.lines
    }

    var text: String {
        buffer.lines.map { AnsiSpans.plain($0) }.joined(separator: "\n")
    }

    var canRerun: Bool {
        last != nil
    }

    @discardableResult
    func start(_ invocation: RunInvocation) -> Int? {
        guard !isRunning else {
            return nil
        }
        nextId += 1
        return launch(invocation, id: nextId)
    }

    @discardableResult
    private func launch(_ invocation: RunInvocation, id: Int) -> Int? {
        runId = id
        stopping = false
        last = invocation
        buffer.clear()
        status = nil
        command = invocation.argv.joined(separator: " ")
        isRunning = true
        onChange?()
        runner.start(invocation, runId: id) { [weak self] lineId, line in
            self?.append(line, runId: lineId)
        } onFinish: { [weak self] finish in
            self?.finished(finish, id: id)
        }
        return id
    }

    func rerun() {
        guard let last else {
            return
        }
        start(last)
    }

    @discardableResult
    func stopAndStart(_ invocation: RunInvocation) -> Int? {
        guard isRunning else {
            return start(invocation)
        }
        nextId += 1
        let id = nextId
        queued = (id, invocation)
        stopping = true
        runner.stop()
        return id
    }

    func stop() {
        queued = nil
        stopping = true
        runner.stop()
    }

    func clear() {
        buffer.clear()
        status = nil
    }

    func append(_ line: String) {
        append(line, runId: runId)
    }

    func append(_ line: String, runId: Int) {
        guard runId == self.runId else {
            return
        }
        guard let filter = lineFilter else {
            buffer.append(line)
            return
        }
        if let shown = filter(runId, line) {
            buffer.append(shown)
        }
    }

    func observeWorkspace(_ publisher: Published<URL?>.Publisher) {
        workspaceSink = publisher.dropFirst().sink { [weak self] _ in
            self?.stop()
        }
    }

    private func finished(_ finish: RunFinish, id: Int) {
        guard id == runId else {
            return
        }
        isRunning = false
        switch finish {
        case let .exited(code):
            status = code == 0 ? "exit 0" : "exit \(code)"
        case let .signalled(code):
            status = stopping ? "stopped" : "signal \(code)"
        case let .failed(message):
            status = message
            append(message)
        }
        stopping = false
        onFinish?(id, finish)
        onChange?()
        if let next = queued {
            queued = nil
            launch(next.invocation, id: next.id)
        }
    }
}
