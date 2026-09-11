import Combine
import Foundation

final class RunOutput: ObservableObject {
    static let maxLines = 5000

    @Published private(set) var buffer = RunOutputBuffer(maxLines: RunOutput.maxLines)
    @Published private(set) var isRunning = false
    @Published private(set) var status: String?
    @Published private(set) var command: String?

    var onChange: (() -> Void)?
    private let runner = ProcessRunner()
    private var last: RunInvocation?
    private var queued: RunInvocation?
    private var workspaceSink: AnyCancellable?

    var lines: [String] {
        buffer.lines
    }

    var text: String {
        buffer.lines.map { AnsiSpans.plain($0) }.joined(separator: "\n")
    }

    var canRerun: Bool {
        last != nil
    }

    func start(_ invocation: RunInvocation) {
        guard !isRunning else {
            return
        }
        last = invocation
        buffer.clear()
        status = nil
        command = invocation.argv.joined(separator: " ")
        isRunning = true
        onChange?()
        runner.start(invocation) { [weak self] line in
            self?.append(line)
        } onFinish: { [weak self] finish in
            self?.finished(finish)
        }
    }

    func rerun() {
        guard let last else {
            return
        }
        start(last)
    }

    func stopAndStart(_ invocation: RunInvocation) {
        guard isRunning else {
            start(invocation)
            return
        }
        queued = invocation
        runner.stop()
    }

    func stop() {
        queued = nil
        runner.stop()
    }

    func clear() {
        buffer.clear()
        status = nil
    }

    func append(_ line: String) {
        buffer.append(line)
    }

    func observeWorkspace(_ publisher: Published<URL?>.Publisher) {
        workspaceSink = publisher.dropFirst().sink { [weak self] _ in
            self?.stop()
        }
    }

    private func finished(_ finish: RunFinish) {
        isRunning = false
        switch finish {
        case let .exited(code):
            status = code == 0 ? "exit 0" : "exit \(code)"
        case let .signalled(code):
            status = "signal \(code)"
        case let .failed(message):
            status = message
            append(message)
        }
        onChange?()
        if let next = queued {
            queued = nil
            start(next)
        }
    }
}
