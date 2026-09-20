import Foundation

struct AIExtraFile: Equatable {
    let path: String
    let text: String
}

struct AIPromptInput: Equatable {
    let language: String
    let path: String
    let prefix: String
    let suffix: String
    let extras: [AIExtraFile]
}

enum AIPrompt {
    static let cursor = "<|cursor|>"
    static let system = """
    You complete code inside an editor. The user message contains the file being edited with \(cursor) marking the caret, and sometimes other files from the same project for context. Reply with JSON only, shaped as {"suggestions":[{"label":"short summary","text":"code to insert"}]}. Give one to three suggestions, best first. Each text is inserted verbatim at the caret: it continues exactly what is already typed on the caret line, never repeats text before the caret, and contains no explanation and no markdown fences. Prefer completing the current statement or block; stop at a natural boundary.
    """

    static let askSystem = """
    You are a coding assistant inside the Ride editor. The user message holds files from the project, the file being edited with \(cursor) at the caret, optionally the user's selection inside <selection> tags, and a request. Answer the request for exactly this code. Use markdown, put code in fenced blocks with the language name, and keep prose short.
    """

    static func ask(_ input: AIPromptInput, request: String, selection: String?) -> String {
        var out = user(input)
        if let selection, !selection.isEmpty {
            out += "\n\n<selection>\n\(selection)\n</selection>"
        }
        return out + "\n\nRequest: \(request)"
    }

    static func user(_ input: AIPromptInput) -> String {
        var out = ""
        for extra in input.extras {
            out += "<file path=\"\(extra.path)\">\n\(extra.text)\n</file>\n\n"
        }
        out += "<file path=\"\(input.path)\" language=\"\(input.language)\" editing=\"true\">\n"
        out += input.prefix + cursor + input.suffix
        out += "\n</file>"
        return out
    }

    static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "suggestions": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "label": ["type": "string"],
                        "text": ["type": "string"],
                    ],
                    "required": ["label", "text"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["suggestions"],
        "additionalProperties": false,
    ]
}

enum AIResponseParser {
    static func suggestions(in text: String) -> [AISuggestion] {
        guard let object = json(in: text) else {
            return []
        }
        let rows: [Any]
        if let dict = object as? [String: Any] {
            rows = dict["suggestions"] as? [Any] ?? []
        } else {
            rows = object as? [Any] ?? []
        }
        return rows.compactMap { row -> AISuggestion? in
            guard let dict = row as? [String: Any], let text = dict["text"] as? String, !text.isEmpty else {
                return nil
            }
            return AISuggestion(text: text, label: dict["label"] as? String ?? "")
        }
    }

    private static func json(in text: String) -> Any? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: data) {
            return parsed
        }
        guard let open = trimmed.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            return nil
        }
        let closer: Character = trimmed[open] == "{" ? "}" : "]"
        guard let close = trimmed.lastIndex(of: closer), close > open,
              let data = String(trimmed[open...close]).data(using: .utf8)
        else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data)
    }
}

enum AIContextWindow {
    static let prefixLimit = 12_000
    static let suffixLimit = 4_000
    static let fileLimit = 6_000

    static func clip(prefix: String, suffix: String) -> (prefix: String, suffix: String) {
        (tail(prefix, limit: prefixLimit), head(suffix, limit: suffixLimit))
    }

    static func head(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        let cut = text.index(text.startIndex, offsetBy: limit)
        let end = text[..<cut].lastIndex(of: "\n") ?? cut
        return String(text[..<end])
    }

    static func tail(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        let cut = text.index(text.endIndex, offsetBy: -limit)
        let start = text[cut...].firstIndex(of: "\n").map { text.index(after: $0) } ?? cut
        return String(text[start...])
    }
}
