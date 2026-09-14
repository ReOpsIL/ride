import Foundation

struct UsageRow: Equatable {
    let path: String
    let line: UInt32
    let byteStart: UInt32
    let byteEnd: UInt32
    let enclosingItem: String
    let enclosingKind: String
    let inDefinitionScope: Bool
}

struct UsageFileGroup: Equatable, Identifiable {
    let path: String
    let rows: [UsageRow]
    var id: String { path }
    var name: String { path.split(separator: "/").last.map(String.init) ?? path }
    var count: Int { rows.count }
}

enum UsageGrouping {
    static func group(_ rows: [UsageRow]) -> [UsageFileGroup] {
        var order: [String] = []
        var byPath: [String: [UsageRow]] = [:]
        for row in rows {
            if byPath[row.path] == nil {
                order.append(row.path)
            }
            byPath[row.path, default: []].append(row)
        }
        return order.map { path in
            let sorted = (byPath[path] ?? []).sorted { $0.byteStart < $1.byteStart }
            return UsageFileGroup(path: path, rows: sorted)
        }
    }

    static func split(_ rows: [UsageRow]) -> (primary: [UsageFileGroup], other: [UsageFileGroup]) {
        (group(rows.filter { $0.inDefinitionScope }), group(rows.filter { !$0.inDefinitionScope }))
    }

    static func total(_ groups: [UsageFileGroup]) -> Int {
        groups.reduce(0) { $0 + $1.count }
    }
}
