import AppKit

final class FoldController {
    static let shared = FoldController()
    private var refreshing: Set<ObjectIdentifier> = []

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

    func toggle(line: Int, in pane: RideTextView? = nil) {
        guard let view = pane ?? EditorPanes.shared.focusedView else {
            return
        }
        view.window?.makeFirstResponder(view)
        refreshStarts(view)
        guard let target = EditorCommands.target(), let bounds = view.lineRange(line) else {
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
        guard let document = view.hooks.binding?()?.document else {
            return
        }
        guard document.hasSession else {
            view.folds.setStartLines([])
            return
        }
        if let ranges = SessionService.shared.readNow(document, { $0.foldRanges(sessionId: $1) }) {
            view.folds.setStartLines(startLines(ranges, in: view))
        }
    }

    func scheduleStarts(_ view: RideTextView) {
        guard let document = view.hooks.binding?()?.document else {
            return
        }
        guard document.hasSession else {
            view.folds.setStartLines([])
            return
        }
        let key = ObjectIdentifier(view)
        let mark = document.textGeneration
        guard !refreshing.contains(key) else {
            return
        }
        let started = SessionService.shared.read(document, { $0.foldRanges(sessionId: $1) }, then: { [weak self, weak view] ranges in
            self?.refreshing.remove(key)
            guard let self, let view else {
                return
            }
            if document.textGeneration == mark {
                view.folds.setStartLines(self.startLines(ranges, in: view))
            }
            (view.enclosingScrollView?.superview as? EditorHostView)?.gutter.needsDisplay = true
        })
        if started {
            refreshing.insert(key)
        }
    }

    private func startLines(_ ranges: [FoldRange], in view: RideTextView) -> Set<Int> {
        let map = Utf16Map(view.string)
        let index = view.lineIndex()
        return Set(ranges.map { index.line(at: map.utf16(byte: Int($0.startByte))) })
    }

    private func ranges(for target: EditorTarget) -> [NSRange]? {
        let map = Utf16Map(target.text)
        return target.session { $0.foldRanges(sessionId: $1) }?.map { map.nsRange(startByte: $0.startByte, endByte: $0.endByte) }
    }

    func restore(document: BufferDocument, view: RideTextView) {
        refreshStarts(view)
        applyStoredFolds(document: document, view: view)
    }

    private func applyStoredFolds(document: BufferDocument, view: RideTextView) {
        guard !document.foldStarts.isEmpty,
              let ranges = SessionService.shared.readNow(document, { $0.foldRanges(sessionId: $1) })
        else {
            return
        }
        let map = Utf16Map(view.string)
        let wanted = Set(document.foldStarts)
        let before = view.folds
        view.folds.removeAll()
        let kept = ranges.filter { wanted.contains($0.startByte) && $0.endByte > $0.startByte }
        for range in kept {
            view.folds.add(map.nsRange(startByte: range.startByte, endByte: range.endByte))
        }
        document.foldStarts = kept.map(\.startByte)
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
