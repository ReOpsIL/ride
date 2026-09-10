import AppKit

struct CompletionList {
    let base: [CompletionHit]
    let replaceUtf16: Int
    let truncated: Bool
    let site: CompletionSiteKind

    init(response: CompletionResponse, text: String) {
        base = response.hits
        replaceUtf16 = Utf16.utf16Offset(in: text, utf8: Int(response.replaceStartByte))
        truncated = response.truncated
        site = response.site
    }

    func narrowed(_ prefix: String) -> [CompletionHit] {
        truncated ? base : CompletionNarrowing.filter(base, prefix: prefix) { $0.name }
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
