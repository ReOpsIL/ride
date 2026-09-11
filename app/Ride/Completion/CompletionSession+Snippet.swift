import Foundation

extension CompletionSession {
    func insertSnippet(_ text: String, snippet: Bool, replacing range: NSRange, in view: RideTextView) {
        if snippet {
            let parsed = SnippetParser.parse(text)
            if !parsed.stops.isEmpty, let current = self.snippet, current.contains(range) {
                _ = current.push(parsed, replacing: range, in: view)
                return
            }
        }
        if let session = SnippetInsert.insert(text, snippet: snippet, replacing: range, in: view) {
            self.snippet = session
        }
    }

    func snippetNext() -> Bool {
        guard let snippet else {
            return false
        }
        if !snippet.next() {
            self.snippet = nil
        }
        return true
    }

    func snippetPrevious() -> Bool {
        guard let snippet else {
            return false
        }
        snippet.previous()
        return true
    }

    func endSnippet() -> Bool {
        guard let snippet else {
            return false
        }
        if !snippet.end() {
            self.snippet = nil
        }
        return true
    }

    func keepSnippet(range: NSRange, length: Int) {
        if let snippet, !snippet.textChanged(range: range, insertedLength: length) {
            self.snippet = nil
        }
    }
}
