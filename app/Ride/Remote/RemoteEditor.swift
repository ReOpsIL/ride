import Combine
import Foundation

enum RemoteProbeState {
    case idle
    case running
    case finished(checks: [RemoteCheck], command: String)
    case rejected(String)
}

final class RemoteEditor: ObservableObject {
    @Published var draft = RemoteToolchain.off {
        didSet {
            if draft != oldValue, !isIdle {
                stopTest()
            }
        }
    }
    @Published private(set) var probe = RemoteProbeState.idle

    private let runner = RemoteProbe()

    var isTesting: Bool {
        if case .running = probe {
            return true
        }
        return false
    }

    func load(_ toolchain: RemoteToolchain) {
        stopTest()
        draft = toolchain
        if draft.port == 0 {
            draft.port = 22
        }
    }

    func test(_ link: RemoteLink) {
        let invocation: RunInvocation
        do {
            invocation = try RemoteLaunch.probe(link)
        } catch {
            probe = .rejected(RemoteLaunch.explain(error))
            return
        }
        probe = .running
        let command = invocation.argv.joined(separator: " ")
        runner.start(invocation) { [weak self] result in
            self?.finish(result, link: link, command: command)
        }
    }

    func stopTest() {
        runner.stop()
        probe = .idle
    }

    private var isIdle: Bool {
        if case .idle = probe {
            return true
        }
        return false
    }

    private func finish(_ result: RemoteProbeResult, link: RemoteLink, command: String) {
        switch result {
        case let .output(text):
            do {
                probe = .finished(checks: try RemoteLaunch.report(link, output: text), command: command)
            } catch {
                probe = .rejected(RemoteLaunch.explain(error))
            }
        case .timedOut:
            probe = .rejected("No answer after \(Int(RemoteProbe.limit)) seconds.")
        case let .failed(message):
            probe = .rejected(message)
        }
    }
}
