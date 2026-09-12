import Foundation

enum PeekSegments {
    static let limit = 8

    static func labels(_ all: [String], expanded: Bool) -> [String] {
        guard !expanded, all.count > limit else {
            return all
        }
        return Array(all.prefix(limit)) + ["+\(all.count - limit)"]
    }

    static func isMore(_ all: [String], expanded: Bool, index: Int) -> Bool {
        !expanded && all.count > limit && index == limit
    }

    static func selection(_ all: [String], expanded: Bool, index: Int) -> Int {
        let shown = labels(all, expanded: expanded).count
        guard index < shown else {
            return 0
        }
        return index
    }
}
