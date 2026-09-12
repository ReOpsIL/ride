import CryptoKit
import Foundation

enum SingleFileRun {
    static let extensions: Set<String> = ["c", "cpp", "cc", "cxx", "c++", "rs"]

    static func canRun(path: String?) -> Bool {
        guard let path else {
            return false
        }
        return extensions.contains(URL(fileURLWithPath: path).pathExtension)
    }

    static func outputName(for path: String) -> String {
        let digest = SHA256.hash(data: Data(path.utf8))
        return "single/" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

final class SingleFileChain {
    static let shared = SingleFileChain()

    private var next: RunInvocation?
    private var state = RunChainState()

    func expect(_ invocation: RunInvocation?, after runId: Int) {
        next = invocation
        state.expect(runId: runId)
    }

    func cancel() {
        next = nil
        state.cancel()
    }

    func take(runId: Int, status: RunFinish) -> RunInvocation? {
        let pending = next
        guard state.take(runId: runId, status: status) else {
            return nil
        }
        next = nil
        return pending
    }
}
