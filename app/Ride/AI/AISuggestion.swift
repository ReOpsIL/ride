import Foundation

struct AISuggestion: Equatable {
    let text: String
    let label: String

    var name: String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? label : trimmed
    }
}

enum AIContextLevel: String, CaseIterable {
    case block
    case function
    case file
    case directory
    case project

    var title: String {
        switch self {
        case .block: return "Code block"
        case .function: return "Function"
        case .file: return "File"
        case .directory: return "Directory"
        case .project: return "Project"
        }
    }
}

enum AIProvider: String, CaseIterable {
    case anthropic
    case openrouter

    var title: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openrouter: return "OpenRouter"
        }
    }

    /// Fast, cheap models suit completion while typing; the first preset is the default.
    var defaultModel: String {
        presets[0].id
    }

    var presets: [AIModelPreset] {
        switch self {
        case .anthropic:
            return [
                AIModelPreset(id: "claude-haiku-4-5", title: "Claude Haiku 4.5 (fast, cheap)"),
                AIModelPreset(id: "claude-sonnet-5", title: "Claude Sonnet 5"),
                AIModelPreset(id: "claude-opus-5", title: "Claude Opus 5"),
            ]
        case .openrouter:
            return [
                AIModelPreset(id: "anthropic/claude-haiku-4.5", title: "Claude Haiku 4.5 (fast, cheap)"),
                AIModelPreset(id: "anthropic/claude-sonnet-5", title: "Claude Sonnet 5"),
                AIModelPreset(id: "anthropic/claude-opus-5", title: "Claude Opus 5"),
                AIModelPreset(id: "mistralai/codestral-2508", title: "Codestral 2508 (code, cheapest)"),
                AIModelPreset(id: "qwen/qwen3-coder-flash", title: "Qwen3 Coder Flash (code, cheapest)"),
            ]
        }
    }
}

/// Status-bar text for a finished completion request.
enum AIOutcome {
    static func text(count: Int, shown: Bool) -> String {
        if count == 0 {
            return "AI: no suggestion"
        }
        let noun = count == 1 ? "suggestion" : "suggestions"
        return shown ? "AI: \(count) \(noun)" : "AI: \(count) \(noun) (caret moved)"
    }
}

struct AIModelPreset: Equatable, Identifiable {
    let id: String
    let title: String
}

/// What the model picker shows for a stored preference: a preset id, or `custom` for anything else.
enum AIModelChoice {
    static let custom = "custom"

    static func selection(model: String, provider: AIProvider, editingCustom: Bool) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespaces)
        if editingCustom {
            return custom
        }
        if trimmed.isEmpty {
            return provider.defaultModel
        }
        return provider.presets.contains { $0.id == trimmed } ? trimmed : custom
    }
}

enum AIAuthMode: String, CaseIterable {
    case login
    case key
}

struct AIConfig: Equatable {
    let provider: AIProvider
    let model: String
    let auth: AIAuthMode
    let level: AIContextLevel

    init(provider: String, model: String, auth: String, level: String) {
        self.provider = AIProvider(rawValue: provider) ?? .anthropic
        let trimmed = model.trimmingCharacters(in: .whitespaces)
        self.model = trimmed.isEmpty ? self.provider.defaultModel : trimmed
        self.auth = AIAuthMode(rawValue: auth) ?? .login
        self.level = AIContextLevel(rawValue: level) ?? .function
    }
}
