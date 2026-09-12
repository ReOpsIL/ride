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

    func expect(_ invocation: RunInvocation?) {
        next = invocation
    }

    func cancel() {
        next = nil
    }

    func take(_ finish: RunFinish) -> RunInvocation? {
        let pending = next
        next = nil
        guard case .exited(0) = finish else {
            return nil
        }
        return pending
    }
}
