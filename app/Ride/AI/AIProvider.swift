import Foundation

enum AIProvider: String, CaseIterable {
    case anthropic
    case openrouter

    var title: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openrouter: return "OpenRouter"
        }
    }

    var defaultModel: String {
        presets[0].id
    }

    var defaultChatModel: String {
        chatPresets[0].id
    }

    var presets: [AIModelPreset] {
        switch self {
        case .anthropic:
            return [
                AIModelPreset(id: "claude-haiku-4-5", title: "Claude Haiku 4.5 (fast, cheap)"),
                AIModelPreset(id: "claude-sonnet-5-5", title: "Claude Sonnet 5.5"),
                AIModelPreset(id: "claude-opus-5-5", title: "Claude Opus 5.5"),
            ]
        case .openrouter:
            return [
                AIModelPreset(id: "anthropic/claude-haiku-4.5", title: "Claude Haiku 4.5 (fast, cheap)"),
                AIModelPreset(id: "anthropic/claude-sonnet-5.5", title: "Claude Sonnet 5.5"),
                AIModelPreset(id: "anthropic/claude-opus-5.5", title: "Claude Opus 5.5"),
                AIModelPreset(id: "mistralai/codestral-2508", title: "Codestral 2508 (code, cheapest)"),
                AIModelPreset(id: "qwen/qwen3-coder-flash", title: "Qwen3 Coder Flash (code, cheapest)"),
            ]
        }
    }

    var chatPresets: [AIModelPreset] {
        switch self {
        case .anthropic:
            return [
                AIModelPreset(id: "claude-opus-5-5", title: "Claude Opus 5.5 (best answers)"),
                AIModelPreset(id: "claude-sonnet-5-5", title: "Claude Sonnet 5.5 (faster)"),
                AIModelPreset(id: "claude-haiku-4-5", title: "Claude Haiku 4.5 (fastest, cheapest)"),
            ]
        case .openrouter:
            return [
                AIModelPreset(id: "anthropic/claude-opus-5.5", title: "Claude Opus 5.5 (best answers)"),
                AIModelPreset(id: "anthropic/claude-sonnet-5.5", title: "Claude Sonnet 5.5 (faster)"),
                AIModelPreset(id: "anthropic/claude-haiku-4.5", title: "Claude Haiku 4.5 (fastest, cheapest)"),
            ]
        }
    }
}
