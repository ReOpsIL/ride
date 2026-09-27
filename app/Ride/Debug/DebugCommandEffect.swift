import Foundation

enum DebugCommandEffect {
    static func resumes(_ command: DebugCommand) -> Bool {
        switch command {
        case .continue, .next, .stepIn, .stepOut:
            return true
        case .pause, .disconnect:
            return false
        }
    }

    static func disconnects(_ command: DebugCommand) -> Bool {
        if case .disconnect = command {
            return true
        }
        return false
    }
}
