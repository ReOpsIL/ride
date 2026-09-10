import AppKit

extension SessionService {
    func paint(_ update: SessionUpdate?, document: BufferDocument, view: RideTextView, text: String) {
        guard let update else {
            return
        }
        mergeHighlights(document: document, update: update)
        HighlightApply.apply(update, text: text, view: view)
        if let outline = update.outline {
            document.outline = outline.map(Self.row)
        }
        Underlines.apply(document: document, view: view, parseErrors: update.errors)
    }

    private func mergeHighlights(document: BufferDocument, update: SessionUpdate) {
        if !update.changed.isEmpty {
            document.highlights.removeAll { span in
                update.changed.contains { c in
                    span.endByte > c.startByte && span.startByte < c.endByte
                }
            }
        }
        document.highlights.append(contentsOf: update.highlights)
    }
}
