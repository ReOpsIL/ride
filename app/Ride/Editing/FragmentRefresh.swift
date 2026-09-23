import AppKit

extension RideTextView {
    func refreshFolds(from previous: FoldSet) {
        refreshFragments(in: FoldSet.changed(from: previous, to: folds))
    }

    func refreshVision(from previous: [VisionLine]) {
        let changed = Set(previous).symmetricDifference(visionLines()).map(\.line)
        refreshFragments(in: changed.compactMap(lineRange(_:)))
    }

    func refreshFragments(in ranges: [NSRange]) {
        guard let tlm = textLayoutManager, let storage = textContentStorage, let backing = storage.textStorage else {
            return
        }
        let text = backing.string as NSString
        let paragraphs = ranges
            .map { text.paragraphRange(for: RangeShift.clamp($0, length: text.length)) }
            .filter { $0.length > 0 }
        guard !paragraphs.isEmpty else {
            return
        }
        storage.performEditingTransaction {
            for paragraph in paragraphs {
                backing.edited(.editedAttributes, range: paragraph, changeInLength: 0)
            }
        }
        for paragraph in paragraphs {
            if let range = textRange(utf16: paragraph) {
                tlm.ensureLayout(for: range)
            }
        }
        tlm.textViewportLayoutController.layoutViewport()
        needsDisplay = true
        (enclosingScrollView?.superview as? EditorHostView)?.gutter.needsDisplay = true
    }

    func lineRange(_ line: Int) -> NSRange? {
        let starts = lineIndex().starts
        guard line >= 1, line <= starts.count else {
            return nil
        }
        let end = line < starts.count ? starts[line] : (string as NSString).length
        return NSRange(location: starts[line - 1], length: end - starts[line - 1])
    }
}
