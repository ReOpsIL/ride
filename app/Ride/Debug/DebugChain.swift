import Foundation

final class DebugChain {
    static let shared = DebugChain()

    private var pending: DebugLaunch?
    private var state = RunChainState()

    func expect(_ launch: DebugLaunch, after runId: Int) {
        pending = launch
        state.expect(runId: runId)
    }

    func cancel() {
        pending = nil
        state.cancel()
    }

    func take(runId: Int, status: RunFinish) -> DebugLaunch? {
        let launch = pending
        guard state.take(runId: runId, status: status) else {
            return nil
        }
        pending = nil
        return launch
    }
}
