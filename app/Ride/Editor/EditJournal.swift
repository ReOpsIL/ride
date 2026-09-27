import Foundation

struct ByteEdit: Equatable {
    let start: UInt32
    let oldEnd: UInt32
    let newEnd: UInt32

    func map(_ position: UInt32, towardEnd: Bool) -> UInt32 {
        if position <= start {
            return position
        }
        if position >= oldEnd {
            return UInt32(Int64(position) + Int64(newEnd) - Int64(oldEnd))
        }
        return towardEnd ? newEnd : start
    }

    static func caret(_ caret: UInt32, of edit: ByteEdit, among edits: [ByteEdit]) -> UInt32 {
        let before = edits.filter { $0 != edit && $0.oldEnd <= edit.start }
        let delta = before.reduce(Int64(0)) { $0 + Int64($1.newEnd) - Int64($1.oldEnd) }
        return UInt32(max(0, Int64(caret) + delta))
    }

    func shifted<S: ByteSpan>(_ spans: [S], rebuild: (S, UInt32, UInt32) -> S) -> [S] {
        ByteSpanShift.shifted(spans, start: start, oldEnd: oldEnd, newEnd: newEnd, rebuild: rebuild)
    }

    func covering<S: ByteSpan>(_ spans: [S], rebuild: (S, UInt32, UInt32) -> S) -> [S] {
        spans.map { rebuild($0, map($0.startByte, towardEnd: false), map($0.endByte, towardEnd: true)) }
    }
}

struct EditJournal {
    static let capacity = 256
    private(set) var generation = 0
    private var entries: [ByteEdit] = []

    mutating func record(_ edit: ByteEdit) {
        generation += 1
        entries.append(edit)
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    func edits(since mark: Int) -> [ByteEdit]? {
        let missing = generation - mark
        guard missing >= 0, missing <= entries.count else {
            return nil
        }
        return Array(entries.suffix(missing))
    }
}
