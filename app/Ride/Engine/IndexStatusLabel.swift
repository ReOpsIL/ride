import Foundation

extension IndexStatus {
    var warningCount: UInt32 {
        warnings
    }
}

enum IndexStatusLabel {
    static func text(_ status: IndexStatus) -> String {
        let skipped = status.warningCount > 0 ? " · \(status.warningCount) skipped" : ""
        switch status.state {
        case .idle:
            return status.rustSrcAvailable ? "idle" : "idle · rust-src missing"
        case .indexing:
            return "indexing \(status.cratesDone)/\(status.cratesTotal)" + skipped
        case .ready:
            return "ready · \(status.docs) docs" + skipped
        case .rebuilding:
            return "rebuilding"
        case .error:
            return "index error" + skipped
        }
    }

    static func detail(_ status: IndexStatus) -> String? {
        guard let message = status.message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty
        else {
            return nil
        }
        return message
    }
}
