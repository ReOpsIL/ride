import Foundation

struct ProcessRow: Identifiable, Equatable {
    let pid: UInt32
    let parent: UInt32
    let name: String
    let path: String

    var id: UInt32 {
        pid
    }
}

enum ProcessFilter {
    static func matching(_ rows: [ProcessRow], query: String) -> [ProcessRow] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else {
            return rows
        }
        return rows.filter { row in
            row.name.lowercased().contains(needle) || String(row.pid).hasPrefix(needle)
        }
    }
}
