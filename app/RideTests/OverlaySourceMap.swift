import Foundation

struct OverlaySourceMap {
    let text: String
    let starts: [Int]

    init(_ text: String) {
        self.text = text
        let ns = text as NSString
        var out = [0]
        var index = 0
        while index < ns.length {
            var end = 0
            ns.getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: index, length: 0))
            if end <= index {
                break
            }
            if end < ns.length {
                out.append(end)
            }
            index = end
        }
        starts = out
    }

    func line(at utf16: Int) -> Int {
        var lo = 0
        var hi = starts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= utf16 {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo + 1
    }

    func lineStart(_ line: Int) -> Int {
        guard line >= 1, line <= starts.count else {
            return 0
        }
        return starts[line - 1]
    }

    func range(of needle: String, occurrence: Int) -> NSRange {
        let ns = text as NSString
        var seen = 0
        var search = NSRange(location: 0, length: ns.length)
        while search.length > 0 {
            let hit = ns.range(of: needle, options: [], range: search)
            if hit.location == NSNotFound {
                break
            }
            seen += 1
            if seen == occurrence {
                return hit
            }
            let next = NSMaxRange(hit)
            search = NSRange(location: next, length: ns.length - next)
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    func label(_ path: String, _ range: NSRange, _ text: String) -> StoredLabel {
        StoredLabel(
            path: path,
            byteStart: UInt32(range.location),
            byteEnd: UInt32(NSMaxRange(range)),
            lineStart: UInt32(line(at: range.location)),
            lineEnd: UInt32(line(at: range.location)),
            column: 1,
            text: text,
            macroName: nil
        )
    }
}
