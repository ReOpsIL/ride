import AppKit

extension EditorCommands {
    static func selectLine() {
        run { target in
            let line = (target.text as NSString).lineRange(for: target.selection)
            return EditResult(changes: [], selection: line)
        }
    }

    static func selectWord() {
        run { target in
            let range = IdentifierRange.at(target.text as NSString, index: target.selection.location) ?? target.selection
            return EditResult(changes: [], selection: range)
        }
    }

    static func extendSelection() {
        guard let target = target(), let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let text = target.text
        let start = UInt32(Utf16.utf8Offset(in: text, utf16: target.selection.location))
        let end = UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(target.selection)))
        let ranges = engine.enclosingRanges(sessionId: id, startByte: start, endByte: end)
        guard let next = ranges.first else {
            return
        }
        target.view.selectionStack.append(target.selection)
        let range = Utf16.nsRange(in: text, startByte: next.startByte, endByte: next.endByte)
        target.view.setSelectedRange(range)
    }

    static func shrinkSelection() {
        guard let target = target(), let previous = target.view.selectionStack.popLast() else {
            return
        }
        target.view.setSelectedRange(previous)
    }

    static func matchingBrace() {
        guard let target = target(), let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: target.text, utf16: target.selection.location))
        guard let pair = engine.bracketPair(sessionId: id, byte: byte) else {
            return
        }
        let open = Utf16.utf16Offset(in: target.text, utf8: Int(pair.openByte))
        let close = Utf16.utf16Offset(in: target.text, utf8: Int(pair.closeByte))
        let caret = target.selection.location
        let destination = abs(caret - open) <= 1 ? close : open
        target.state.recordLocation()
        EditorPanes.shared.focused?.select(NSRange(location: destination, length: 0))
    }
}
