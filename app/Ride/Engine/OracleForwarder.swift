import Foundation

final class OracleForwarder: OracleListener, @unchecked Sendable {
    weak var client: RideEngineClient?

    init(client: RideEngineClient) {
        self.client = client
    }

    func onCompletionsReady(sessionId: UInt64) {
        DispatchQueue.main.async {
            CompletionSession.shared.oracleAnswered(sessionId: sessionId)
        }
    }

    func onOracleStatus(status: OracleStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.client?.oracleStatus = status
        }
    }
}
