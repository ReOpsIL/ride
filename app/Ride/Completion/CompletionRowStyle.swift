import AppKit

enum CompletionRowStyle {
    static var theme: Theme { HighlightApply.theme }
    static let sysroot: Set<String> = ["core", "alloc", "std", "proc_macro", "test"]

    static func glyph(_ kind: ItemKind) -> String {
        switch kind {
        case .keyword: return "k"
        case .local: return "l"
        case .crate: return "cr"
        case .mod: return "mod"
        case .`struct`: return "S"
        case .`enum`: return "E"
        case .union: return "U"
        case .trait: return "T"
        case .fn: return "fn"
        case .method: return "m"
        case .macro: return "!"
        case .const: return "c"
        case .type: return "ty"
        case .`static`: return "st"
        case .heading: return "#"
        case .`class`: return "cls"
        case .namespace: return "ns"
        }
    }

    static func color(_ kind: ItemKind) -> NSColor {
        switch kind {
        case .keyword: return theme.keyword
        case .local: return theme.variable
        case .crate, .mod, .namespace: return theme.property
        case .`struct`, .`enum`, .union, .trait, .type, .`class`: return theme.type
        case .fn, .method: return theme.function
        case .macro: return theme.macro
        case .const, .`static`: return theme.constant
        case .heading: return theme.heading
        }
    }

    static func detail(_ hit: CompletionHit) -> String {
        if !hit.signature.isEmpty {
            return hit.signature
        }
        return hit.path == hit.name ? "" : hit.path
    }

    static func origin(_ hit: CompletionHit) -> String {
        if hit.crateName.isEmpty {
            return ""
        }
        if hit.crateVersion.isEmpty || sysroot.contains(hit.crateName) {
            return hit.crateName
        }
        return "\(hit.crateName) \(hit.crateVersion)"
    }

    static func name(_ text: String, prefix: String, chrome: ChromeColors) -> NSAttributedString {
        let font = Tokens.nsMono(12, weight: .semibold)
        let out = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: chrome.textPrimary])
        for range in MatchHighlight.ranges(in: text, query: prefix) {
            out.addAttribute(.foregroundColor, value: chrome.accent, range: range)
        }
        return out
    }

    static func docText(_ hit: CompletionHit) -> String {
        hit.docParagraph.isEmpty ? hit.docFirstSentence : hit.docParagraph
    }

    static func hasDoc(_ hit: CompletionHit) -> Bool {
        !docText(hit).isEmpty
    }
}
