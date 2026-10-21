import AppKit

enum BracketHighlight {
    private static weak var marked: RideTextView?

    static func update(document: BufferDocument, view: RideTextView) {
        guard document.pending == nil else {
            return
        }
        strip()
        view.updateCurrentLineHighlight()
        guard view.selectedRange().length == 0, let pair = query(document: document, view: view) else {
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

    private static func query(document: BufferDocument, view: RideTextView) -> BracketPair? {
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        return SessionService.shared.readNow(document) { $0.bracketPair(sessionId: $1, byte: byte) } ?? nil
    }

    private static func strip() {
        marked?.setBackground(.bracket, ranges: [])
        marked = nil
    }

    private static func paint(_ view: RideTextView, ranges: [NSRange]) {
        view.setBackground(.bracket, ranges: ranges)
        marked = view
    }
}
