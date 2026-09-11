import AppKit

final class SnippetSession {
    private weak var view: RideTextView?
    private var stack = SnippetStack()
    private var ignoreChange = false

    init?(_ snippet: ParsedSnippet, insertedAt location: Int, in view: RideTextView) {
        guard stack.push(snippet, replacing: NSRange(location: location, length: 0)) else {
            return nil
        }
        self.view = view
        select()
    }

    func contains(_ range: NSRange) -> Bool {
        stack.contains(range)
    }

    func push(_ snippet: ParsedSnippet, replacing range: NSRange, in view: RideTextView) -> Bool {
        ignoreChange = true
        view.insertText(snippet.text, replacementRange: range)
        ignoreChange = false
        guard stack.push(snippet, replacing: range) else {
            return false
        }
        self.view = view
        select()
        return true
    }

    func next() -> Bool {
        switch stack.next() {
        case .select(let range):
            select(range)
            return true
        case .caret(let caret):
            view?.setSelectedRange(NSRange(location: caret, length: 0))
            return false
        case .ended:
            return false
        }
    }

    func previous() {
        stack.previous()
        select()
    }

    func end() -> Bool {
        switch stack.cancel() {
        case .select(let range):
            select(range)
            return true
        case .caret, .ended:
            return false
        }
    }

    func textChanged(range: NSRange, insertedLength: Int) -> Bool {
        if ignoreChange {
            ignoreChange = false
            return true
        }
        return stack.textChanged(range: range, insertedLength: insertedLength)
    }

    func shift(range: NSRange, insertedLength: Int) {
        stack.shift(range: range, insertedLength: insertedLength)
    }

    private func select(_ range: NSRange? = nil) {
        guard let range = range ?? stack.selection else {
            return
        }
        view?.setSelectedRange(range)
        view?.scrollRangeToVisible(range)
    }
}
