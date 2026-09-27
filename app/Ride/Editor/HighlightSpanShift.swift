import Foundation

extension HighlightSpan: ByteSpan {
    func moved(_ start: UInt32, _ end: UInt32) -> HighlightSpan {
        HighlightSpan(startByte: start, endByte: end, capture: capture)
    }
}

enum HighlightShift {
    static func apply(document: BufferDocument, edit: ByteEdit) {
        document.highlights = edit.shifted(document.highlights) { $0.moved($1, $2) }
    }
}
