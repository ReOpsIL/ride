import Foundation

enum GitErrorText {
    static func message(_ error: Error) -> String {
        if case let EngineError.Git(message) = error {
            return message
        }
        return "\(error)"
    }

    static func summary(_ output: String, fallback: String) -> String {
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.last { !$0.isEmpty } ?? fallback
    }
}
