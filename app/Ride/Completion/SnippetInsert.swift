import AppKit

enum SnippetInsert {
    static func insert(_ text: String, snippet: Bool, replacing range: NSRange, in view: RideTextView) -> SnippetSession? {
        guard snippet else {
            view.insertText(text, replacementRange: range)
            return nil
        }
        let parsed = SnippetParser.parse(text)
        view.insertText(parsed.text, replacementRange: range)
        if let session = SnippetSession(parsed, insertedAt: range.location, in: view) {
            return session
        }
        view.setSelectedRange(NSRange(location: range.location + parsed.finalOffset, length: 0))
        return nil
    }
}
