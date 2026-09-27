import AppKit

extension CheatGroup {
    init(_ section: CheatSection) {
        title = section.title
        matched = section.matched
        items = section.entries.map { CheatItem(name: $0.name, doc: $0.doc, snippet: $0.snippet) }
    }
}

enum CheatSheetFetch {
    static func run(document: BufferDocument, view: RideTextView, done: @escaping (CheatSheetResponse) -> Void) {
        let cursor = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        SessionService.shared.read(document, { engine, id in
            engine.cheatSheet(sessionId: id, cursorByte: cursor, all: false)
        }, then: done)
    }
}
