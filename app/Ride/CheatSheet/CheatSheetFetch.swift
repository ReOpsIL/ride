import AppKit

extension CheatGroup {
    init(_ section: CheatSection) {
        title = section.title
        matched = section.matched
        items = section.entries.map { CheatItem(name: $0.name, doc: $0.doc, snippet: $0.snippet) }
    }
}

enum CheatSheetFetch {
    static func run(document: BufferDocument, view: RideTextView, all: Bool, done: @escaping (CheatSheetResponse) -> Void) {
        guard let id = document.sessionId else {
            return
        }
        let text = view.string
        let cursor = UInt32(Utf16.utf8Offset(in: text, utf16: view.selectedRange().location))
        RideEngineClient.shared.withEngine { engine in
            engine.cheatSheet(sessionId: id, cursorByte: cursor, all: all)
        } then: { resp in
            done(resp)
        }
    }
}
