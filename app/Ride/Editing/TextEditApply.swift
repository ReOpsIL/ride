import Foundation

extension ByteEdit {
    init(_ edit: TextEdit) {
        self.init(start: edit.startByte, oldEnd: edit.endByte, newEnd: edit.startByte + UInt32(edit.text.utf8.count))
    }
}

enum TextEditApply {
    static func changes(_ edits: [TextEdit], in text: String) -> [TextChange] {
        let map = Utf16Map(text)
        return edits.map { TextChange(range: map.nsRange(startByte: $0.startByte, endByte: $0.endByte), text: $0.text) }
    }

    static func result(_ edits: [TextEdit], caret: TextEdit, in text: String) -> EditResult {
        let changes = changes(edits, in: text)
        let applied = EditResult.applying(changes, to: text)
        let byte = ByteEdit.caret(caret.caretByte, of: ByteEdit(caret), among: edits.map(ByteEdit.init))
        let location = Utf16.utf16Offset(in: applied, utf8: Int(byte))
        return EditResult(changes: changes, selection: NSRange(location: location, length: 0))
    }
}
