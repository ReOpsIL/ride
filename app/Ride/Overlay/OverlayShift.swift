import Foundation

enum OverlayShift {
    static func shifted(_ diagnostic: StoredDiagnostic, replacing edit: NSRange, with length: Int) -> StoredDiagnostic? {
        let labels = [diagnostic.primary] + diagnostic.secondary + diagnostic.notes.flatMap(\.labels)
        let owned = labels.filter { $0.path == diagnostic.path }
        if owned.contains(where: { intersects($0, edit) }) {
            return nil
        }
        let owner = diagnostic.path
        var next = diagnostic
        next.primary = moved(diagnostic.primary, owner: owner, edit: edit, length: length)
        next.secondary = diagnostic.secondary.map { moved($0, owner: owner, edit: edit, length: length) }
        next.notes = diagnostic.notes.map { note in
            var copy = note
            copy.labels = note.labels.map { moved($0, owner: owner, edit: edit, length: length) }
            return copy
        }
        return next
    }

    private static func intersects(_ label: StoredLabel, _ edit: NSRange) -> Bool {
        let start = Int(label.byteStart)
        let end = Int(label.byteEnd)
        if start == end {
            return edit.location <= start && start <= NSMaxRange(edit)
        }
        return edit.location < end && NSMaxRange(edit) > start
    }

    private static func moved(_ label: StoredLabel, owner: String, edit: NSRange, length: Int) -> StoredLabel {
        guard label.path == owner else {
            return label
        }
        let span = NSRange(location: Int(label.byteStart), length: max(0, Int(label.byteEnd) - Int(label.byteStart)))
        let shifted = placed(span, edit: edit, length: length)
        var next = label
        next.byteStart = UInt32(shifted.location)
        next.byteEnd = UInt32(NSMaxRange(shifted))
        return next
    }

    private static func placed(_ span: NSRange, edit: NSRange, length: Int) -> NSRange {
        let shifted = RangeShift.shifted(span, replacing: edit, with: length) ?? span
        if shifted.length == span.length {
            return shifted
        }
        let delta = length - edit.length
        if span.location >= NSMaxRange(edit) {
            return NSRange(location: span.location + delta, length: span.length)
        }
        return span
    }
}
