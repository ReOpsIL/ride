import Foundation

final class RunChain {
    static let shared = RunChain()

    private var next: RunFollowUp = .none
    private var state = RunChainState()

    func expect(_ next: RunFollowUp, after runId: Int) {
        self.next = next
        state.expect(runId: runId)
    }

    func cancel() {
        next = .none
        state.cancel()
    }

    func take(runId: Int, status: RunFinish) -> RunFollowUp {
        guard state.runId == runId else {
            return .none
        }
        let pending = next
        next = .none
        return state.take(runId: runId, status: status) ? pending : .none
    }
}
