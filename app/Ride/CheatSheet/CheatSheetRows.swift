import Foundation

struct CheatItem: Equatable {
    let name: String
    let doc: String
    let snippet: String
}

struct CheatGroup: Equatable {
    let title: String
    let matched: Bool
    let items: [CheatItem]
}

enum CheatRow: Equatable {
    case header(title: String, matched: Bool)
    case entry(CheatItem)

    var isEntry: Bool {
        if case .entry = self {
            return true
        }
        return false
    }

    var entry: CheatItem? {
        if case let .entry(item) = self {
            return item
        }
        return nil
    }
}

enum CheatSheetRows {
    static func rows(_ groups: [CheatGroup]) -> [CheatRow] {
        groups.flatMap { group in
            [CheatRow.header(title: group.title, matched: group.matched)] + group.items.map(CheatRow.entry)
        }
    }

    static func firstEntry(_ rows: [CheatRow]) -> Int? {
        rows.firstIndex(where: \.isEntry)
    }

    static func step(_ rows: [CheatRow], from current: Int, by delta: Int) -> Int {
        guard delta != 0, !rows.isEmpty else {
            return current
        }
        var index = current
        while true {
            let next = index + delta
            guard rows.indices.contains(next) else {
                return current
            }
            index = next
            if rows[index].isEntry {
                return index
            }
        }
    }

    static func selection(_ rows: [CheatRow], keeping name: String?) -> Int? {
        if let name, let index = rows.firstIndex(where: { $0.entry?.name == name }) {
            return index
        }
        return firstEntry(rows)
    }
}
