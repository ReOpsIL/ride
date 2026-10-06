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

enum AIModelChoice {
    static let custom = "custom"

    static func selection(model: String, presets: [AIModelPreset], editingCustom: Bool) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespaces)
        if editingCustom {
            return custom
        }
        if trimmed.isEmpty {
            return presets.first?.id ?? custom
        }
        return presets.contains { $0.id == trimmed } ? trimmed : custom
    }
}

struct AIConfig: Equatable {
    let provider: AIProvider
    let model: String
    let level: AIContextLevel

    init(provider: String, model: String, level: String) {
        self.provider = AIProvider(rawValue: provider) ?? .anthropic
        let trimmed = model.trimmingCharacters(in: .whitespaces)
        self.model = trimmed.isEmpty ? self.provider.defaultModel : trimmed
        self.level = AIContextLevel(rawValue: level) ?? .function
    }
}
