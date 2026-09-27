import Foundation

enum EditBuild {
    static func make(before: String, utf16Range: NSRange, inserted: String) -> InputEditFfi {
        let points = EditPoints(before: before, utf16Range: utf16Range, inserted: inserted)
        return InputEditFfi(
            startByte: UInt32(points.start.byte),
            oldEndByte: UInt32(points.oldEnd.byte),
            newEndByte: UInt32(points.newEnd.byte),
            startRow: points.start.row,
            startColumn: points.start.column,
            oldEndRow: points.oldEnd.row,
            oldEndColumn: points.oldEnd.column,
            newEndRow: points.newEnd.row,
            newEndColumn: points.newEnd.column
        )
    }
}

extension ByteEdit {
    init(_ edit: InputEditFfi) {
        self.init(start: edit.startByte, oldEnd: edit.oldEndByte, newEnd: edit.newEndByte)
    }
}
