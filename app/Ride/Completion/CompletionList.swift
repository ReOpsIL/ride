import AppKit

struct CompletionList {
    let base: [CompletionItem]
    let ai: [AISuggestion]
    let aiAnchor: Int?
    let replaceUtf16: Int
    let truncated: Bool
    let site: CompletionSiteKind?

    init(response: CompletionResponse, text: String, ai: [AISuggestion] = [], aiAnchor: Int? = nil) {
        base = response.hits.map(CompletionItem.engine)
        self.ai = ai
        self.aiAnchor = aiAnchor
        replaceUtf16 = Utf16.utf16Offset(in: text, utf8: Int(response.replaceStartByte))
        truncated = response.truncated
        site = response.site
    }

    init(ai: [AISuggestion], anchor: Int) {
        base = []
        self.ai = ai
        aiAnchor = anchor
        replaceUtf16 = anchor
        truncated = false
        site = nil
    }

    private init(base: [CompletionItem], ai: [AISuggestion], aiAnchor: Int?, replaceUtf16: Int, truncated: Bool, site: CompletionSiteKind?) {
        self.base = base
        self.ai = ai
        self.aiAnchor = aiAnchor
        self.replaceUtf16 = replaceUtf16
        self.truncated = truncated
        self.site = site
    }

    func merging(ai: [AISuggestion], anchor: Int) -> CompletionList {
        CompletionList(base: base, ai: ai, aiAnchor: anchor, replaceUtf16: replaceUtf16, truncated: truncated, site: site)
    }

    func narrowed(_ prefix: String, in view: NSTextView) -> [CompletionItem] {
        let engine = truncated ? base : CompletionNarrowing.filter(base, prefix: prefix) { $0.name }
        return aiItems(in: view) + engine
    }

    private func aiItems(in view: NSTextView) -> [CompletionItem] {
        guard let aiAnchor else {
            return []
        }
        let typed = Self.typed(in: view, from: aiAnchor)
        return ai.filter { $0.text.hasPrefix(typed) && $0.text.count > typed.count }.map(CompletionItem.ai)
    }

    static func typed(in view: NSTextView, from start: Int) -> String {
        let ns = view.string as NSString
        let caret = min(view.selectedRange().location, ns.length)
        let from = min(max(start, 0), caret)
        return ns.substring(with: NSRange(location: from, length: caret - from))
    }

    static func lineBeforeCaret(_ view: NSTextView) -> String {
        let ns = view.string as NSString
        let caret = min(view.selectedRange().location, ns.length)
        let start = ns.lineRange(for: NSRange(location: caret, length: 0)).location
        return ns.substring(with: NSRange(location: start, length: caret - start))
    }
}
