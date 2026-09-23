import Foundation

struct FoldSet: Equatable {
    private(set) var ranges: [NSRange] = []
    private var startLines: Set<Int> = []
    private(set) var startsDirty = true

    var isEmpty: Bool {
        ranges.isEmpty
    }

    static func == (lhs: FoldSet, rhs: FoldSet) -> Bool {
        lhs.ranges == rhs.ranges
    }

    mutating func add(_ range: NSRange) {
        guard range.length > 0, !ranges.contains(range) else {
            return
        }
        ranges.append(range)
        ranges.sort { $0.location < $1.location }
    }

    @discardableResult
    mutating func remove(containing location: Int) -> Bool {
        let inside = ranges.filter { $0.location <= location && location <= NSMaxRange($0) }
        guard let innermost = inside.min(by: { $0.length < $1.length }) else {
            return false
        }
        ranges.removeAll { $0 == innermost }
        return true
    }

    mutating func removeAll() {
        ranges = []
        startLines = []
        startsDirty = true
    }

    func hides(_ range: NSRange) -> Bool {
        ranges.contains { $0.location < range.location && NSMaxRange(range) <= NSMaxRange($0) }
    }

    func startsFold(at range: NSRange) -> Bool {
        ranges.contains { $0.location >= range.location && $0.location < NSMaxRange(range) }
    }

    func isFoldStart(line: Int) -> Bool {
        startLines.contains(line)
    }

    mutating func setStartLines(_ lines: Set<Int>) {
        startLines = lines
        startsDirty = false
    }

    func clampCaret(_ location: Int) -> Int {
        for range in ranges where range.location < location && location < NSMaxRange(range) {
            return NSMaxRange(range)
        }
        return location
    }

    @discardableResult
    mutating func textChanged(range: NSRange, insertedLength: Int) -> [NSRange] {
        let delta = insertedLength - range.length
        var released: [NSRange] = []
        ranges = ranges.compactMap { fold in
            if NSMaxRange(range) <= fold.location {
                return NSRange(location: fold.location + delta, length: fold.length)
            }
            if range.location >= NSMaxRange(fold) {
                return fold
            }
            let start = min(fold.location, range.location)
            released.append(NSRange(location: start, length: max(0, NSMaxRange(fold) + delta - start)))
            return nil
        }
        startLines = []
        startsDirty = true
        return released
    }

    static func changed(from old: FoldSet, to new: FoldSet) -> [NSRange] {
        Array(Set(old.ranges).symmetricDifference(new.ranges))
    }
}
