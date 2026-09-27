import AppKit

struct SelfTestEditor {
    let state: AppState

    var view: RideTextView? {
        EditorPanes.shared.focusedView
    }

    var text: String {
        view?.string ?? ""
    }

    var lines: [String] {
        text.components(separatedBy: "\n")
    }

    func line(_ number: Int) -> String {
        lines.indices.contains(number - 1) ? lines[number - 1] : ""
    }

    func lineRange(_ number: Int) -> NSRange {
        guard let view else {
            return NSRange(location: 0, length: 0)
        }
        let starts = view.lineIndex().starts
        let start = starts[min(max(number, 1), starts.count) - 1]
        return (text as NSString).lineRange(for: NSRange(location: start, length: 0))
    }

    func caret(line number: Int, column: Int = 1) {
        let range = lineRange(number)
        view?.setSelectedRange(NSRange(location: range.location + column - 1, length: 0))
    }

    func selectLines(_ from: Int, _ to: Int) {
        let a = lineRange(from)
        let b = lineRange(to)
        view?.setSelectedRange(NSRange(location: a.location, length: NSMaxRange(b) - a.location))
    }

    var caretLine: Int {
        guard let view else {
            return 0
        }
        return view.lineIndex().line(at: view.selectedRange().location)
    }

    var selectedText: String {
        guard let view else {
            return ""
        }
        return (text as NSString).substring(with: view.selectedRange())
    }

    func undo() {
        view?.undo(nil)
    }

    func focus() {
        guard let view else {
            return
        }
        view.window?.makeFirstResponder(view)
    }

    func activate() {
        guard let view else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(view)
    }

    func type(_ text: String) {
        guard let view else {
            return
        }
        for ch in text {
            let s = String(ch)
            let loc = view.selectedRange().location
            view.insertText(s, replacementRange: NSRange(location: loc, length: 0))
            view.setSelectedRange(NSRange(location: loc + (s as NSString).length, length: 0))
        }
    }

    func place(on needle: String, atEnd: Bool = false) {
        guard let view else {
            return
        }
        let range = (view.string as NSString).range(of: needle)
        guard range.location != NSNotFound else {
            return
        }
        let loc = atEnd ? NSMaxRange(range) : range.location
        view.setSelectedRange(NSRange(location: loc, length: 0))
    }

    func expect(_ condition: Bool, _ message: @autoclosure () -> String) -> String? {
        condition ? nil : message()
    }
}
