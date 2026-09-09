import AppKit

enum DiagnosticUnderlines {
    static let style = NSUnderlineStyle.single.union(.patternDot).rawValue

    static func apply(document: BufferDocument, view: RideTextView) {
        guard let storage = view.textStorage else {
            return
        }
        let length = storage.length
        storage.beginEditing()
        for old in document.diagnosticRanges where NSMaxRange(old) <= length {
            storage.removeAttribute(.underlineStyle, range: old)
            storage.removeAttribute(.underlineColor, range: old)
        }
        document.diagnosticRanges = []
        let text = view.string
        if let path = document.fileURL?.path {
            for diag in CheckService.shared.diagnostics where diag.path == path {
                guard let ns = DiagnosticRange.nsRange(in: text, byteStart: diag.byteStart, byteEnd: diag.byteEnd)
                else {
                    continue
                }
                storage.addAttribute(.underlineStyle, value: style, range: ns)
                storage.addAttribute(.underlineColor, value: color(diag.level), range: ns)
                document.diagnosticRanges.append(ns)
            }
        }
        storage.endEditing()
        view.needsDisplay = true
    }

    static func color(_ level: DiagnosticLevel) -> NSColor {
        level == .error ? NSColor.systemRed : NSColor.systemYellow
    }
}
