import Foundation

enum SnippetAdvance: Equatable {
    case select(NSRange)
    case caret(Int)
    case ended
}

struct SnippetFrame: Equatable {
    var stops: [NSRange]
    var current: Int
    var finalCaret: Int
    var origin: NSRange
    var insertedLength: Int
}

struct SnippetStack: Equatable {
    private(set) var frames: [SnippetFrame] = []

    var isEmpty: Bool { frames.isEmpty }
    var depth: Int { frames.count }
    var selection: NSRange? {
        guard let frame = frames.last, frame.stops.indices.contains(frame.current) else {
            return nil
        }
        return frame.stops[frame.current]
    }

    mutating func push(_ snippet: ParsedSnippet, replacing origin: NSRange) -> Bool {
        guard !snippet.stops.isEmpty else {
            return false
        }
        let location = origin.location
        frames.append(
            SnippetFrame(
                stops: snippet.stops.map { NSRange(location: location + $0.range.location, length: $0.range.length) },
                current: 0,
                finalCaret: location + snippet.finalOffset,
                origin: origin,
                insertedLength: snippet.text.utf16.count
            )
        )
        return true
    }

    mutating func next() -> SnippetAdvance {
        while let frame = frames.last {
            if frame.current + 1 < frame.stops.count {
                frames[lastIndex].current += 1
                return .select(frames[lastIndex].stops[frames[lastIndex].current])
            }
            if frames.count == 1 {
                let caret = frame.finalCaret
                frames.removeAll()
                return .caret(caret)
            }
            popInner()
        }
        return .ended
    }

    mutating func previous() {
        guard let frame = frames.last, frame.current > 0 else {
            return
        }
        frames[lastIndex].current -= 1
    }

    mutating func cancel() -> SnippetAdvance {
        guard !frames.isEmpty else {
            return .ended
        }
        if frames.count == 1 {
            frames.removeAll()
            return .ended
        }
        popInner()
        if let range = selection {
            return .select(range)
        }
        frames.removeAll()
        return .ended
    }

    func contains(_ range: NSRange) -> Bool {
        guard let stop = selection else {
            return false
        }
        return range.location >= stop.location && NSMaxRange(range) <= NSMaxRange(stop)
    }

    mutating func textChanged(range: NSRange, insertedLength: Int) -> Bool {
        guard var frame = frames.last else {
            return false
        }
        let stop = frame.stops[frame.current]
        guard range.location >= stop.location, NSMaxRange(range) <= NSMaxRange(stop) else {
            return false
        }
        let delta = insertedLength - range.length
        frame.stops[frame.current].length += delta
        shiftStops(in: &frame, from: NSMaxRange(stop), by: delta, excluding: frame.current)
        frame.insertedLength += delta
        frames[lastIndex] = frame
        return true
    }

    mutating func shift(range: NSRange, insertedLength: Int) {
        let delta = insertedLength - range.length
        let position = NSMaxRange(range)
        for i in frames.indices {
            shiftStops(in: &frames[i], from: position, by: delta, excluding: nil)
            if frames[i].origin.location >= position {
                frames[i].origin.location += delta
            }
        }
    }

    private var lastIndex: Int { frames.count - 1 }

    private mutating func popInner() {
        let inner = frames.removeLast()
        var parent = frames[lastIndex]
        parent.stops = parent.stops.compactMap {
            RangeShift.shifted($0, replacing: inner.origin, with: inner.insertedLength)
        }
        parent.finalCaret = shiftedCaret(parent.finalCaret, replacing: inner.origin, with: inner.insertedLength)
        parent.insertedLength += inner.insertedLength - inner.origin.length
        if parent.current >= parent.stops.count {
            parent.current = max(0, parent.stops.count - 1)
        }
        frames[lastIndex] = parent
    }

    private func shiftedCaret(_ caret: Int, replacing edit: NSRange, with length: Int) -> Int {
        let point = NSRange(location: caret, length: 0)
        guard let shifted = RangeShift.shifted(point, replacing: edit, with: length) else {
            return edit.location + length
        }
        return shifted.location
    }

    private func shiftStops(in frame: inout SnippetFrame, from position: Int, by delta: Int, excluding: Int?) {
        for i in frame.stops.indices where i != excluding && frame.stops[i].location >= position {
            frame.stops[i].location += delta
        }
        if frame.finalCaret >= position {
            frame.finalCaret += delta
        }
    }
}
