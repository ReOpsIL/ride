import Foundation

final class LineIndex {
    private(set) var starts: [Int] = [0]
    private var length = -1
    private var dirty = true

    func invalidate() {
        dirty = true
    }

    func refresh(_ ns: NSString) {
        if !dirty, ns.length == length {
            return
        }
        var out = [0]
        let n = ns.length
        var idx = 0
        while idx < n {
            var end = 0
            ns.getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: idx, length: 0))
            if end <= idx {
                break
            }
            if end < n {
                out.append(end)
            }
            idx = end
        }
        starts = out
        length = n
        dirty = false
    }

    var lineCount: Int {
        starts.count
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

    func column(at utf16: Int) -> Int {
        utf16 - starts[line(at: utf16) - 1] + 1
    }
}
