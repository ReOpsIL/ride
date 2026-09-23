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
        let before = target.view.folds
        target.view.folds.add(innermost)
        after(target.view, caret: innermost.location, before: before)
    }

    func unfold() {
        guard let target = EditorCommands.target() else {
            return
        }
        let caret = target.selection.location
        let before = target.view.folds
        guard target.view.folds.remove(containing: caret) else {
            return
        }
        after(target.view, caret: caret, before: before)
    }

    func foldAll() {
        guard let target = EditorCommands.target(), let ranges = ranges(for: target) else {
            return
        }
        let before = target.view.folds
        for range in ranges {
            target.view.folds.add(range)
        }
        after(target.view, caret: 0, before: before)
    }

    func unfoldAll() {
        guard let target = EditorCommands.target() else {
            return
        }
        let before = target.view.folds
        target.view.folds.removeAll()
        after(target.view, caret: target.selection.location, before: before)
    }

    func toggle(line: Int) {
        guard let view = EditorPanes.shared.focusedView else {
            return
        }
        view.window?.makeFirstResponder(view)
        refreshStarts(view)
        guard let target = EditorCommands.target(), let bounds = lineRange(line, in: view) else {
            return
        }
        if let folded = target.view.folds.ranges.first(where: { NSLocationInRange($0.location, bounds) }) {
            target.view.setSelectedRange(NSRange(location: folded.location, length: 0))
            unfold()
            return
        }
        guard let ranges = ranges(for: target) else {
            return
        }
        let matching = ranges.filter { NSLocationInRange($0.location, bounds) }
        guard let chosen = matching.min(by: { $0.length < $1.length }) else {
            return
        }
        target.view.setSelectedRange(NSRange(location: chosen.location, length: 0))
        fold()
    }

    func refreshStarts(_ view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        if !binding.document.hasSession {
            view.folds.setStartLines([])
            return
        }
        guard let id = binding.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let text = view.string
        let index = view.lineIndex()
        let lines = Set(engine.foldRanges(sessionId: id).map { range in
            index.line(at: Utf16.nsRange(in: text, startByte: range.startByte, endByte: range.endByte).location)
        })
        view.folds.setStartLines(lines)
    }

    private func ranges(for target: EditorTarget) -> [NSRange]? {
        guard let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return nil
        }
        let text = target.text
        return engine.foldRanges(sessionId: id).map { Utf16.nsRange(in: text, startByte: $0.startByte, endByte: $0.endByte) }
    }

    private func lineRange(_ line: Int, in view: RideTextView) -> NSRange? {
        let starts = view.lineIndex().starts
        guard line >= 1, line <= starts.count else {
            return nil
        }
        let start = starts[line - 1]
        let end = line < starts.count ? starts[line] : (view.string as NSString).length
        return NSRange(location: start, length: max(0, end - start))
    }

    func restore(document: BufferDocument, view: RideTextView) {
        refreshStarts(view)
        applyStoredFolds(document: document, view: view)
    }

    private func applyStoredFolds(document: BufferDocument, view: RideTextView) {
        guard !document.foldStarts.isEmpty,
              let id = document.sessionId,
              let engine = RideEngineClient.shared.engine
        else {
            return
        }
        let text = view.string
        let wanted = Set(document.foldStarts)
        let ranges = engine.foldRanges(sessionId: id)
        let before = view.folds
        view.folds.removeAll()
        for range in ranges where wanted.contains(range.startByte) {
            view.folds.add(Utf16.nsRange(in: text, startByte: range.startByte, endByte: range.endByte))
        }
        document.foldStarts = view.folds.ranges.map { range in
            UInt32(Utf16.utf8Offset(in: text, utf16: range.location))
        }
        view.refreshFolds(from: before)
    }

    private func after(_ view: RideTextView, caret: Int, before: FoldSet) {
        view.setSelectedRange(NSRange(location: caret, length: 0))
        refreshStarts(view)
        view.refreshFolds(from: before)
        rememberFolds(view)
    }

    private func rememberFolds(_ view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        let text = view.string
        binding.document.foldStarts = view.folds.ranges.map { range in
            UInt32(Utf16.utf8Offset(in: text, utf16: range.location))
        }
        binding.state.scheduleWorkspaceSave()
    }
}
