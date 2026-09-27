import Foundation

struct SurroundTemplate: Equatable {
    enum Shape: Equatable {
        case inline
        case block(indentBody: Bool)
    }

    let title: String
    let open: String
    let close: String
    var shape = Shape.inline
    var placeholder: String?
}

enum SurroundTemplates {
    static func all(for language: BufferLanguage, tokens: CommentTokens) -> [SurroundTemplate] {
        generic + specific(language) + comment(tokens)
    }

    private static let generic = [
        SurroundTemplate(title: "{ … }", open: "{", close: "}"),
        SurroundTemplate(title: "( … )", open: "(", close: ")"),
        SurroundTemplate(title: "[ … ]", open: "[", close: "]"),
        SurroundTemplate(title: "\" … \"", open: "\"", close: "\""),
    ]

    private static let rust = [
        block("if", "if condition {", placeholder: "condition"),
        block("loop", "loop {"),
        block("unsafe", "unsafe {"),
        block("match", "match value {", placeholder: "value"),
        SurroundTemplate(title: "Some( … )", open: "Some(", close: ")"),
        SurroundTemplate(title: "Ok( … )", open: "Ok(", close: ")"),
    ]

    private static let cFamily = [
        block("if", "if (condition) {", placeholder: "condition"),
        block("while", "while (condition) {", placeholder: "condition"),
        SurroundTemplate(title: "#if 0 … #endif", open: "#if 0", close: "#endif", shape: .block(indentBody: false)),
    ]

    private static func specific(_ language: BufferLanguage) -> [SurroundTemplate] {
        switch language {
        case .rust: rust
        case .c, .cpp: cFamily
        default: []
        }
    }

    private static func comment(_ tokens: CommentTokens) -> [SurroundTemplate] {
        guard let open = tokens.blockOpen, let close = tokens.blockClose else {
            return []
        }
        return [SurroundTemplate(title: "\(open) … \(close)", open: open + " ", close: " " + close)]
    }

    private static func block(_ title: String, _ open: String, placeholder: String? = nil) -> SurroundTemplate {
        SurroundTemplate(title: title, open: open, close: "}", shape: .block(indentBody: true), placeholder: placeholder)
    }
}
