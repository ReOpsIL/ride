import Foundation

extension HighlightSpan: ByteSpan {}

enum HighlightShift {
    static func apply(document: BufferDocument, edit: InputEditFfi) {
        document.highlights = ByteSpanShift.shifted(
            document.highlights,
            start: edit.startByte,
            oldEnd: edit.oldEndByte,
            newEnd: edit.newEndByte,
            rebuild: { span, start, end in
                HighlightSpan(startByte: start, endByte: end, capture: span.capture)
            }
        )
    }
}
