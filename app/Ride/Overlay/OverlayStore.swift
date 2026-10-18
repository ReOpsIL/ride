import Foundation

struct OverlayEntry: Equatable {
    var diagnostic: StoredDiagnostic
    var stale: Bool
}

struct OverlayStore {
    private(set) var version: UInt64?
    private(set) var entries: [OverlayEntry] = []

    var fresh: [StoredDiagnostic] {
        entries.compactMap { $0.stale ? nil : $0.diagnostic }
    }

    mutating func reload(version: UInt64, diagnostics: [StoredDiagnostic]) {
        guard self.version != version else {
            return
        }
        self.version = version
        entries = diagnostics.map { OverlayEntry(diagnostic: $0, stale: false) }
    }

    mutating func shift(before: String, range: NSRange, inserted: String) {
        let start = Utf16.utf8Offset(in: before, utf16: range.location)
        let end = Utf16.utf8Offset(in: before, utf16: NSMaxRange(range))
        let edit = NSRange(location: start, length: max(0, end - start))
        let bytes = inserted.utf8.count
        entries = entries.map { shifted($0, edit: edit, bytes: bytes) }
    }

    private func shifted(_ entry: OverlayEntry, edit: NSRange, bytes: Int) -> OverlayEntry {
        if entry.stale {
            return entry
        }
        guard let next = OverlayShift.shifted(entry.diagnostic, replacing: edit, with: bytes) else {
            return OverlayEntry(diagnostic: entry.diagnostic, stale: true)
        }
        return OverlayEntry(diagnostic: next, stale: false)
    }
}
