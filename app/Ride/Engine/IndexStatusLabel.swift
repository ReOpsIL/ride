import Foundation

enum IndexStatusLabel {
    static func text(_ status: IndexStatus) -> String {
        let skipped = status.warnings > 0 ? " · \(status.warnings) skipped" : ""
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
        let message = status.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = [message, status.rustSrcAvailable ? "" : RustSrc.hint].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}
