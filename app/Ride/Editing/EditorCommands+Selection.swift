import AppKit

extension EditorCommands {
    static func selectLine() {
        run(editing: false) { target in
            let line = (target.text as NSString).lineRange(for: target.selection)
            return EditResult(changes: [], selection: line)
        }
    }

    static func selectWord() {
        run(editing: false) { target in
            let range = IdentifierRange.at(target.text as NSString, index: target.selection.location) ?? target.selection
            return EditResult(changes: [], selection: range)
        }
    }

    static func extendSelection() {
        guard let target = target(editing: false) else {
            return
        }
        let ranges = target.session {
            $0.enclosingRanges(sessionId: $1, startByte: target.caretByte, endByte: target.selectionEndByte)
        } ?? []
        guard let next = ranges.first else {
            return
        }
        target.view.selectionStack.append(target.selection)
        target.view.setSelectedRange(Utf16Map(target.text).nsRange(startByte: next.startByte, endByte: next.endByte))
    }

    static func shrinkSelection() {
        guard let target = target(editing: false), let previous = target.view.selectionStack.popLast() else {
            return
        }
        target.view.setSelectedRange(previous)
    }

    static func matchingBrace() {
        guard let target = target(editing: false), let pair = target.session({ $0.bracketPair(sessionId: $1, byte: target.caretByte) }) else {
            return
        }
        let map = Utf16Map(target.text)
        let open = map.utf16(byte: Int(pair.openByte))
        let close = map.utf16(byte: Int(pair.closeByte))
        let caret = target.selection.location
        let destination = abs(caret - open) <= 1 ? close : open
        target.state.recordLocation()
        EditorPanes.shared.focused?.select(NSRange(location: destination, length: 0))
    }
}
