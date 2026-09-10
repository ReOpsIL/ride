import AppKit

struct DiagnosticUnderline {
    var range: NSRange
    let level: DiagnosticLevel
}

enum Underlines {
    static let diagnosticStyle = NSUnderlineStyle.thick.union(.patternDot).rawValue
    static let parseStyle = NSUnderlineStyle.single.union(.patternDot).rawValue

    static func shift(document: BufferDocument, replacing edit: NSRange, with length: Int) {
        document.parseUnderlines = RangeShift.shifted(document.parseUnderlines, replacing: edit, with: length)
        document.diagnosticUnderlines = document.diagnosticUnderlines.compactMap { item in
            RangeShift.shifted(item.range, replacing: edit, with: length).map {
                DiagnosticUnderline(range: $0, level: item.level)
            }
        }
    }

    static func apply(document: BufferDocument, view: RideTextView, parseErrors: [ParseErrorSpan]?) {
        guard let storage = view.textStorage else {
            return
        }
        let text = view.string
        let length = storage.length
        storage.beginEditing()
        clear(document.parseUnderlines, in: storage)
        clear(document.diagnosticUnderlines.map(\.range), in: storage)
        if let parseErrors {
            document.parseUnderlines = parseRanges(parseErrors, text: text, length: length)
        }
        if document.diagnosticsVersion != CheckService.shared.version {
            document.diagnosticsVersion = CheckService.shared.version
            document.diagnosticUnderlines = diagnosticRanges(document: document, text: text, length: length)
        }
        for range in document.parseUnderlines {
            add(RangeShift.clamp(range, length: length), style: parseStyle, color: HighlightApply.theme.error, to: storage)
        }
        for item in document.diagnosticUnderlines {
            add(RangeShift.clamp(item.range, length: length), style: diagnosticStyle, color: color(item.level), to: storage)
        }
        storage.endEditing()
        view.lines.refresh(text as NSString)
        (view.enclosingScrollView?.superview as? EditorHostView)?.gutter.diagnosticLines = gutterLines(document, view: view)
        view.needsDisplay = true
    }

    static func color(_ level: DiagnosticLevel) -> NSColor {
        let chrome = ThemeStore.shared.chrome
        return level == .error ? chrome.error : chrome.warning
    }

    private static func clear(_ ranges: [NSRange], in storage: NSTextStorage) {
        for old in ranges {
            let range = RangeShift.clamp(old, length: storage.length)
            if range.length > 0 {
                storage.removeAttribute(.underlineStyle, range: range)
                storage.removeAttribute(.underlineColor, range: range)
            }
        }
    }

    private static func add(_ range: NSRange, style: Int, color: NSColor, to storage: NSTextStorage) {
        if range.length > 0 {
            storage.addAttribute(.underlineStyle, value: style, range: range)
            storage.addAttribute(.underlineColor, value: color, range: range)
        }
    }

    private static func parseRanges(_ errors: [ParseErrorSpan], text: String, length: Int) -> [NSRange] {
        if errors.isEmpty {
            return []
        }
        let map = Utf16Map(text)
        return errors.compactMap { err in
            let range = RangeShift.clamp(map.nsRange(startByte: err.startByte, endByte: err.endByte), length: length)
            return range.length > 0 ? range : nil
        }
    }

    private static func diagnosticRanges(document: BufferDocument, text: String, length: Int) -> [DiagnosticUnderline] {
        guard let path = document.fileURL?.path else {
            return []
        }
        let mine = CheckService.shared.diagnostics.filter { $0.path == path }
        if mine.isEmpty {
            return []
        }
        let map = Utf16Map(text)
        return mine.compactMap { diag in
            DiagnosticRange.nsRange(map: map, length: length, byteStart: diag.byteStart, byteEnd: diag.byteEnd)
                .map { DiagnosticUnderline(range: $0, level: diag.level) }
        }
    }

    private static func gutterLines(_ document: BufferDocument, view: RideTextView) -> [Int: DiagnosticLevel] {
        var lines: [Int: DiagnosticLevel] = [:]
        for item in document.diagnosticUnderlines {
            let line = view.lines.line(at: item.range.location)
            if lines[line] != .error {
                lines[line] = item.level == .error ? .error : .warning
            }
        }
        return lines
    }
}
