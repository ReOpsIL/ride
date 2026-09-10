import AppKit

final class SnippetSession {
    private weak var view: RideTextView?
    private var stops: [NSRange]
    private var finalCaret: Int
    private var current = 0

    init?(_ snippet: ParsedSnippet, insertedAt location: Int, in view: RideTextView) {
        guard !snippet.stops.isEmpty else {
            return nil
        }
        self.view = view
        stops = snippet.stops.map { NSRange(location: location + $0.range.location, length: $0.range.length) }
        finalCaret = location + snippet.finalOffset
        select()
    }

    func next() -> Bool {
        if current + 1 < stops.count {
            current += 1
            select()
            return true
        }
        view?.setSelectedRange(NSRange(location: finalCaret, length: 0))
        return false
    }

    func previous() {
        guard current > 0 else {
            return
        }
        current -= 1
        select()
    }

    func textChanged(range: NSRange, insertedLength: Int) -> Bool {
        let stop = stops[current]
        guard range.location >= stop.location, NSMaxRange(range) <= NSMaxRange(stop) else {
            return false
        }
        let delta = insertedLength - range.length
        stops[current].length += delta
        shiftStops(from: NSMaxRange(stop), by: delta, excluding: current)
        return true
    }

    func shift(range: NSRange, insertedLength: Int) {
        shiftStops(from: NSMaxRange(range), by: insertedLength - range.length, excluding: nil)
    }

    private func shiftStops(from position: Int, by delta: Int, excluding: Int?) {
        for i in stops.indices where i != excluding && stops[i].location >= position {
            stops[i].location += delta
        }
        if finalCaret >= position {
            finalCaret += delta
        }
    }

    private func select() {
        view?.setSelectedRange(stops[current])
        view?.scrollRangeToVisible(stops[current])
    }
}
