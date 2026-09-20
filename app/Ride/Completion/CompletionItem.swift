import Foundation

enum CompletionItem {
    case engine(CompletionHit)
    case ai(AISuggestion)

    var hit: CompletionHit? {
        if case .engine(let hit) = self {
            return hit
        }
        return nil
    }

    var isAI: Bool {
        hit == nil
    }

    var name: String {
        switch self {
        case .engine(let hit): return hit.name
        case .ai(let suggestion): return suggestion.name
        }
    }

    var insertText: String {
        switch self {
        case .engine(let hit): return hit.insertText
        case .ai(let suggestion): return suggestion.text
        }
    }

    var snippet: Bool {
        hit?.snippet ?? false
    }

    var deprecated: Bool {
        hit?.deprecated ?? false
    }

    var importPath: String? {
        hit?.importPath
    }

    var sourcePath: String? {
        hit?.sourcePath
    }

    var replaceStartByte: UInt32? {
        hit?.replaceStartByte
    }

    var itemKind: ItemKind? {
        hit?.itemKind
    }

    var signature: String {
        hit?.signature ?? ""
    }

    var label: String {
        if case .ai(let suggestion) = self {
            return suggestion.label
        }
        return ""
    }
}
