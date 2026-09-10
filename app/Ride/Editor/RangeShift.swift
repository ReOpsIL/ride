import Foundation

enum RangeShift {
    static func shifted(_ range: NSRange, replacing edit: NSRange, with length: Int) -> NSRange? {
        let delta = length - edit.length
        let end = NSMaxRange(range)
        let editEnd = NSMaxRange(edit)
        if end < edit.location {
            return range
        }
        if range.location > editEnd {
            return NSRange(location: range.location + delta, length: range.length)
        }
        let start = min(range.location, edit.location)
        let newEnd = max(end, editEnd) + delta
        return newEnd > start ? NSRange(location: start, length: newEnd - start) : nil
    }

    static func shifted(_ ranges: [NSRange], replacing edit: NSRange, with length: Int) -> [NSRange] {
        ranges.compactMap { shifted($0, replacing: edit, with: length) }
    }

    static func clamp(_ range: NSRange, length: Int) -> NSRange {
        let loc = min(max(range.location, 0), length)
        let end = min(max(NSMaxRange(range), loc), length)
        return NSRange(location: loc, length: end - loc)
    }
}
