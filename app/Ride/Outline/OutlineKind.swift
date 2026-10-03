import SwiftUI

enum OutlineKind {
    @ViewBuilder
    static func badge(_ label: String) -> some View {
        if label == OutlineTree.scopeKind {
            KindBadge(kind: .type, letter: "i")
        } else {
            KindBadge(kind: itemKind(label))
        }
    }

    static func itemKind(_ label: String) -> ItemKind {
        switch label {
        case "mod": return .mod
        case "struct": return .struct
        case "enum": return .enum
        case "union": return .union
        case "trait": return .trait
        case "fn": return .fn
        case "method": return .method
        case "macro": return .macro
        case "const": return .const
        case "static": return .static
        case "heading": return .heading
        case "class": return .`class`
        case "namespace": return .namespace
        case "field": return .field
        case "table": return .table
        case "target": return .target
        case "variant": return .variant
        case "header": return .header
        default: return .type
        }
    }
}
