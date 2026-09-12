import Foundation

enum RunFinish: Equatable {
    case exited(Int32)
    case signalled(Int32)
    case failed(String)

    var isClean: Bool {
        switch self {
        case .exited:
            return true
        case .signalled, .failed:
            return false
        }
    }

    var succeeded: Bool {
        self == .exited(0)
    }
}
