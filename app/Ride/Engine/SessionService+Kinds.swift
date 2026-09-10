import Foundation

extension SessionService {
    static func kindLabel(_ kind: ItemKind) -> String {
        switch kind {
        case .keyword: return "kw"
        case .local: return "local"
        case .crate: return "crate"
        case .mod: return "mod"
        case .`struct`: return "struct"
        case .`enum`: return "enum"
        case .union: return "union"
        case .trait: return "trait"
        case .fn: return "fn"
        case .method: return "method"
        case .macro: return "macro"
        case .const: return "const"
        case .type: return "type"
        case .`static`: return "static"
        case .heading: return "heading"
        case .`class`: return "class"
        case .namespace: return "namespace"
        case .field: return "field"
        case .table: return "table"
        case .target: return "target"
        case .variant: return "variant"
        case .header: return "header"
        }
    }
}

extension BufferLanguage {
    init(_ lang: Lang) {
        switch lang {
        case .rust: self = .rust
        case .c: self = .c
        case .cpp: self = .cpp
        case .markdown: self = .markdown
        case .toml: self = .toml
        case .make: self = .make
        case .cmake: self = .cmake
        }
    }
}
