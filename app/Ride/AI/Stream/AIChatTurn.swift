import Foundation

enum AIChatRole: String {
    case user
    case assistant
}

struct AIChatTurn: Equatable {
    let role: AIChatRole
    let text: String
}
