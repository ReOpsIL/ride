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
        guard let engine = RideEngineClient.shared.engine, let id = document.sessionId else {
            return
        }
        let text = view.string
        let cursor = UInt32(Utf16.utf8Offset(in: text, utf16: view.selectedRange().location))
        DispatchQueue.global(qos: .userInitiated).async {
            let resp = engine.cheatSheet(sessionId: id, cursorByte: cursor, all: all)
            DispatchQueue.main.async {
                done(resp)
            }
        }
    }
}
