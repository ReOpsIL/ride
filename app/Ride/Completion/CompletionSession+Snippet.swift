import Foundation

extension CompletionSession {
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
        guard snippet != nil else {
            return false
        }
        snippet = nil
        return true
    }

    func keepSnippet(range: NSRange, length: Int) {
        if let snippet, !snippet.textChanged(range: range, insertedLength: length) {
            self.snippet = nil
        }
    }
}
