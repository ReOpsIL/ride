enum ShortcutColumns {
    static func balance(_ groups: [ShortcutGroup], into count: Int) -> [[ShortcutGroup]] {
        guard count > 0 else {
            return []
        }
        let order = Dictionary(uniqueKeysWithValues: groups.enumerated().map { ($1.id, $0) })
        var columns = Array(repeating: [ShortcutGroup](), count: count)
        var heights = Array(repeating: 0, count: count)
        for group in groups.sorted(by: { height($0) > height($1) }) {
            let shortest = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[shortest].append(group)
            heights[shortest] += height(group)
        }
        return columns
            .filter { !$0.isEmpty }
            .map { column in column.sorted { order[$0.id, default: 0] < order[$1.id, default: 0] } }
            .sorted { order[$0[0].id, default: 0] < order[$1[0].id, default: 0] }
    }

    static func height(_ group: ShortcutGroup) -> Int {
        group.entries.count + 1
    }
}
