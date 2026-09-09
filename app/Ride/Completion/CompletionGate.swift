import Foundation

enum CompletionGate {
    static func accept(_ responseId: UInt64, latest: UInt64) -> Bool {
        responseId == latest
    }
}
