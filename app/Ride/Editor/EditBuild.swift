import Foundation

enum EditBuild {
    static func make(before: String, utf16Range: NSRange, inserted: String) -> InputEditFfi {
        let start = Utf16.utf8Offset(in: before, utf16: utf16Range.location)
        let oldEnd = Utf16.utf8Offset(in: before, utf16: utf16Range.location + utf16Range.length)
        let newEnd = start + inserted.utf8.count
        let (startRow, startCol) = Utf16.point(in: before, utf8: start)
        let (oldEndRow, oldEndCol) = Utf16.point(in: before, utf8: oldEnd)
        let ns = before as NSString
        let after = ns.replacingCharacters(in: utf16Range, with: inserted)
        let (newEndRow, newEndCol) = Utf16.point(in: after, utf8: newEnd)
        return InputEditFfi(
            startByte: UInt32(start),
            oldEndByte: UInt32(oldEnd),
            newEndByte: UInt32(newEnd),
            startRow: startRow,
            startColumn: startCol,
            oldEndRow: oldEndRow,
            oldEndColumn: oldEndCol,
            newEndRow: newEndRow,
            newEndColumn: newEndCol
        )
    }
}
