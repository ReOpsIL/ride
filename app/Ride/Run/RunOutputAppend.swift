import Foundation

enum RunOutputAppend {
    struct Plan: Equatable {
        var reset: Bool
        var dropLines: Int
        var appendFrom: Int
        var rendered: Int
    }

    static func plan(first: Int, end: Int, rendered: Int, storedFirst: Int, restyle: Bool) -> Plan {
        guard !restyle, rendered >= first, rendered <= end, storedFirst <= first else {
            return Plan(reset: true, dropLines: 0, appendFrom: 0, rendered: end)
        }
        return Plan(
            reset: false,
            dropLines: first - storedFirst,
            appendFrom: rendered - first,
            rendered: end
        )
    }
}
