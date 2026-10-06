import Foundation

enum AIInlineLine {
    static func restIsBlank(_ text: String, caret: Int) -> Bool {
        let ns = text as NSString
        let loc = min(caret, ns.length)
        var end = 0
        ns.getLineStart(nil, end: nil, contentsEnd: &end, for: NSRange(location: loc, length: 0))
        return ns.substring(with: NSRange(location: loc, length: max(0, end - loc))).trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func typedThrough(_ text: String, ghost: AIInlineGhost, caret: Int) -> Bool {
        let ns = text as NSString
        guard caret >= ghost.location, caret <= ns.length else {
            return false
        }
        let typed = ns.substring(with: NSRange(location: ghost.location, length: caret - ghost.location))
        return ghost.remaining.hasPrefix(typed)
    }

    static func beforeCaret(_ text: String, caret: Int) -> String {
        let ns = text as NSString
        let loc = min(caret, ns.length)
        let start = ns.lineRange(for: NSRange(location: loc, length: 0)).location
        return ns.substring(with: NSRange(location: start, length: loc - start))
    }
}
