import AppKit

enum BracketHighlight {
    private static weak var marked: RideTextView?
    private static var marks: [NSRange] = []

    static func update(document: BufferDocument, view: RideTextView) {
        strip()
        view.updateCurrentLineHighlight()
        guard document.pending == nil, view.selectedRange().length == 0,
              let pair = query(document: document, view: view)
        else {
            return
        }
        let text = view.string
        let open = Utf16.utf16Offset(in: text, utf8: Int(pair.openByte))
        let close = Utf16.utf16Offset(in: text, utf8: Int(pair.closeByte))
        paint(view, ranges: [
            NSRange(location: open, length: 1),
            NSRange(location: close, length: 1),
        ])
    }

    static func restore(_ view: RideTextView) {
        guard marked === view, !marks.isEmpty else {
            return
        }
        paint(view, ranges: marks)
    }

    private static func query(document: BufferDocument, view: RideTextView) -> BracketPair? {
        guard let id = document.sessionId, let engine = RideEngineClient.shared.engine else {
            return nil
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        return engine.bracketPair(sessionId: id, byte: byte)
    }

    private static func strip() {
        guard let view = marked, let tlm = view.textLayoutManager else {
            marked = nil
            marks = []
            return
        }
        for range in marks {
            if let tr = view.textRange(utf16: range) {
                tlm.removeRenderingAttribute(.backgroundColor, for: tr)
            }
        }
        marked = nil
        marks = []
    }

    private static func paint(_ view: RideTextView, ranges: [NSRange]) {
        guard let tlm = view.textLayoutManager else {
            return
        }
        let color = ThemeStore.shared.chrome.accent.withAlphaComponent(0.3)
        let length = (view.string as NSString).length
        var applied: [NSRange] = []
        for range in ranges {
            let clamped = RangeShift.clamp(range, length: length)
            guard clamped.length > 0, let tr = view.textRange(utf16: clamped) else {
                continue
            }
            tlm.addRenderingAttribute(.backgroundColor, value: color, for: tr)
            applied.append(clamped)
        }
        marks = applied
        marked = view
        view.needsDisplay = true
    }
}
