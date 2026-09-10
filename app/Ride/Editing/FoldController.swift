import AppKit

final class FoldController {
    static let shared = FoldController()

    func fold() {
        guard let target = EditorCommands.target(), let ranges = ranges(for: target) else {
            return
        }
        let caret = target.selection.location
        let candidates = ranges.filter { $0.location <= caret && caret <= NSMaxRange($0) }
        guard let innermost = candidates.min(by: { $0.length < $1.length }) else {
            return
        }
        target.view.folds.add(innermost)
        after(target.view, caret: innermost.location)
    }

    func unfold() {
        guard let target = EditorCommands.target() else {
            return
        }
        let caret = target.selection.location
        guard target.view.folds.remove(containing: caret) else {
            return
        }
        after(target.view, caret: caret)
    }

    func foldAll() {
        guard let target = EditorCommands.target(), let ranges = ranges(for: target) else {
            return
        }
        for range in ranges {
            target.view.folds.add(range)
        }
        after(target.view, caret: 0)
    }

    func unfoldAll() {
        guard let target = EditorCommands.target() else {
            return
        }
        target.view.folds.removeAll()
        after(target.view, caret: target.selection.location)
    }

    private func ranges(for target: EditorTarget) -> [NSRange]? {
        guard let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return nil
        }
        let text = target.text
        return engine.foldRanges(sessionId: id).map { Utf16.nsRange(in: text, startByte: $0.startByte, endByte: $0.endByte) }
    }

    private func after(_ view: RideTextView, caret: Int) {
        view.setSelectedRange(NSRange(location: caret, length: 0))
        view.refreshFolds()
    }
}
