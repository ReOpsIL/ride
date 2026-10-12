import Foundation

extension ReviewHunt {
    var reviewKey: String { "\(path)\n\(item)" }
}

extension ReviewRow {
    var reviewKey: String { "\(path)\n\(item)" }

    var place: String {
        if change == "moved", !oldPath.isEmpty {
            return "\(oldPath) → \(path)"
        }
        if line == 0 {
            return path
        }
        return "\(path):\(line)"
    }
}

enum ReviewStyle {
    static func markLabel(_ row: ReviewRow) -> String {
        if row.mark.isEmpty {
            return "unchecked"
        }
        var parts = [row.mark]
        if !row.markAuthor.isEmpty {
            parts.append(row.markAuthor)
        }
        if !row.markState.isEmpty {
            parts.append(row.markState)
        }
        return parts.joined(separator: " · ")
    }
}

struct ReviewBlock: Identifiable {
    let id: String
    let title: String
    var rows: [ReviewRow]
}

enum ReviewGroups {
    static func rows(_ inbox: ReviewInbox, group: String, module: String?) -> [ReviewRow] {
        inbox.rows.filter { row in
            row.group == group && (module == nil || module == Self.moduleName(row.module) || group != "behaviour")
        }
    }

    static func blocks(_ rows: [ReviewRow], group: String, grouped: Bool) -> [ReviewBlock] {
        if group == "equivalent" {
            let formatting = rows.filter { $0.change != "moved" }
            let moved = rows.filter { $0.change == "moved" }
            return [
                ReviewBlock(id: "formatting", title: "Formatting · \(formatting.count)", rows: formatting),
                ReviewBlock(id: "moved", title: "Moved · \(moved.count)", rows: moved),
            ].filter { !$0.rows.isEmpty }
        }
        guard group == "behaviour", grouped else {
            return rows.isEmpty ? [] : [ReviewBlock(id: "all", title: "", rows: rows)]
        }
        var out: [ReviewBlock] = []
        for row in rows {
            if let last = out.indices.last, out[last].id == row.module {
                out[last].rows.append(row)
            } else {
                let title = row.module.isEmpty ? "crate root" : row.module
                out.append(ReviewBlock(id: row.module, title: title, rows: [row]))
            }
        }
        return out
    }

    static func moduleName(_ module: String) -> String {
        module.split(separator: "/").last.map(String.init) ?? module
    }
}
