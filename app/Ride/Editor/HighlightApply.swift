import AppKit

enum HighlightApply {
    static var theme = Theme.load()

    static func apply(
        _ update: SessionUpdate,
        text: String,
        view: RideTextView,
        errors: inout [NSRange]
    ) {
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        guard let storage = view.textContentStorage?.textStorage else {
            return
        }
        let map = Utf16Map(text)
        storage.beginEditing()
        for range in update.changed {
            let ns = clamp(map.nsRange(startByte: range.startByte, endByte: range.endByte), in: full)
            if ns.length > 0 {
                storage.removeAttribute(.foregroundColor, range: ns)
                storage.addAttribute(.foregroundColor, value: theme.chrome.textPrimary, range: ns)
            }
            if let tlm = view.textLayoutManager, let tr = view.textRange(utf16: ns) {
                tlm.removeRenderingAttribute(.foregroundColor, for: tr)
            }
        }
        for span in update.highlights {
            let ns = clamp(map.nsRange(startByte: span.startByte, endByte: span.endByte), in: full)
            if ns.length == 0 {
                continue
            }
            let color = theme.color(span.capture)
            storage.addAttribute(.foregroundColor, value: color, range: ns)
            if let tlm = view.textLayoutManager, let tr = view.textRange(utf16: ns) {
                tlm.addRenderingAttribute(.foregroundColor, value: color, for: tr)
            }
        }
        storage.endEditing()
        if let tlm = view.textLayoutManager {
            for range in update.changed {
                let ns = clamp(map.nsRange(startByte: range.startByte, endByte: range.endByte), in: full)
                if let tr = view.textRange(utf16: ns) {
                    tlm.invalidateLayout(for: tr)
                }
            }
        }
        storage.beginEditing()
        for old in errors where NSMaxRange(old) <= storage.length {
            storage.removeAttribute(.underlineStyle, range: old)
            storage.removeAttribute(.underlineColor, range: old)
        }
        var next: [NSRange] = []
        for err in update.errors {
            let ns = clamp(map.nsRange(startByte: err.startByte, endByte: err.endByte), in: full)
            if ns.length == 0 {
                continue
            }
            storage.addAttribute(.underlineStyle, value: DiagnosticUnderlines.parseStyle, range: ns)
            storage.addAttribute(.underlineColor, value: theme.error, range: ns)
            next.append(ns)
        }
        storage.endEditing()
        errors = next
        view.needsDisplay = true
        view.updateCurrentLineHighlight()
    }

    static func restyle(spans: [HighlightSpan], text: String, view: RideTextView, visible: ByteRange?) {
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        guard let storage = view.textContentStorage?.textStorage else {
            return
        }
        let map = Utf16Map(text)
        let window = visible.map { map.nsRange(startByte: $0.startByte, endByte: $0.endByte) } ?? full
        storage.beginEditing()
        for span in spans {
            let ns = clamp(map.nsRange(startByte: span.startByte, endByte: span.endByte), in: full)
            if ns.length == 0 || !overlap(ns, window) {
                continue
            }
            storage.addAttribute(.foregroundColor, value: theme.color(span.capture), range: ns)
        }
        storage.endEditing()
        view.needsDisplay = true
    }

    private static func clamp(_ range: NSRange, in full: NSRange) -> NSRange {
        let loc = min(max(range.location, full.location), NSMaxRange(full))
        let end = min(max(NSMaxRange(range), loc), NSMaxRange(full))
        return NSRange(location: loc, length: end - loc)
    }

    private static func overlap(_ a: NSRange, _ b: NSRange) -> Bool {
        NSMaxRange(a) > b.location && NSMaxRange(b) > a.location
    }
}
