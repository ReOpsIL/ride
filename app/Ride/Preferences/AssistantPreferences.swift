import Foundation

struct AssistantPreferences: Codable, Equatable {
    var chatModel: String
    var chatWidth: Double
    var inlineSuggestions: Bool

    static let defaults = AssistantPreferences(chatModel: "", chatWidth: 380, inlineSuggestions: true)

    init(chatModel: String, chatWidth: Double, inlineSuggestions: Bool) {
        self.chatModel = chatModel
        self.chatWidth = chatWidth
        self.inlineSuggestions = inlineSuggestions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.defaults
        chatModel = try c.decodeIfPresent(String.self, forKey: .chatModel) ?? d.chatModel
        chatWidth = try c.decodeIfPresent(Double.self, forKey: .chatWidth) ?? d.chatWidth
        inlineSuggestions = try c.decodeIfPresent(Bool.self, forKey: .inlineSuggestions) ?? d.inlineSuggestions
    }
}
