import AppKit

enum DiagnosticUnderlines {
    static let style = NSUnderlineStyle.single.union(.patternDot).rawValue

    static func apply(document: BufferDocument, view: RideTextView) {
        guard let tlm = view.textLayoutManager else {
            return
        }
        for old in document.diagnosticRanges {
            if let tr = view.textRange(utf16: old) {
                tlm.removeRenderingAttribute(.underlineStyle, for: tr)
                tlm.removeRenderingAttribute(.underlineColor, for: tr)
            }
        }
        document.diagnosticRanges = []
        guard let path = document.fileURL?.path else {
            return
        }
        let text = view.string
        for diag in CheckService.shared.diagnostics where diag.path == path {
            guard let ns = DiagnosticRange.nsRange(in: text, byteStart: diag.byteStart, byteEnd: diag.byteEnd),
                  let tr = view.textRange(utf16: ns)
            else {
                continue
            }
            tlm.addRenderingAttribute(.underlineStyle, value: style, for: tr)
            tlm.addRenderingAttribute(.underlineColor, value: color(diag.level), for: tr)
            document.diagnosticRanges.append(ns)
        }
        view.needsDisplay = true
    }

    static func color(_ level: DiagnosticLevel) -> NSColor {
        level == .error ? NSColor.systemRed : NSColor.systemYellow
    }
}
