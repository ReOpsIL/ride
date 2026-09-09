import AppKit

enum DiagnosticUnderlines {
    static let style = NSUnderlineStyle.thick.union(.patternDot).rawValue
    static let parseStyle = NSUnderlineStyle.single.union(.patternDot).rawValue

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
        var lines: [Int: DiagnosticLevel] = [:]
        if let path = document.fileURL?.path {
            let mine = CheckService.shared.diagnostics.filter { $0.path == path }
            let map = mine.isEmpty ? nil : Utf16Map(view.string)
            for diag in mine {
                guard let map,
                      let ns = DiagnosticRange.nsRange(map: map, length: length, byteStart: diag.byteStart, byteEnd: diag.byteEnd)
                else {
                    continue
                }
                storage.addAttribute(.underlineStyle, value: style, range: ns)
                storage.addAttribute(.underlineColor, value: color(diag.level), range: ns)
                document.diagnosticRanges.append(ns)
                let line = Int(diag.line)
                if lines[line] != .error {
                    lines[line] = diag.level == .error ? .error : .warning
                }
            }
        }
        storage.endEditing()
        (view.enclosingScrollView?.superview as? EditorHostView)?.gutter.diagnosticLines = lines
        view.needsDisplay = true
    }

    static func color(_ level: DiagnosticLevel) -> NSColor {
        let chrome = ThemeStore.shared.chrome
        return level == .error ? chrome.error : chrome.warning
    }
}
