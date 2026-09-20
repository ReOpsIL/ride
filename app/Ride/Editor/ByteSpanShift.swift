import Foundation

protocol ByteSpan {
    var startByte: UInt32 { get }
    var endByte: UInt32 { get }
}

enum ByteSpanShift {
    static func shifted<S: ByteSpan>(
        _ spans: [S],
        start: UInt32,
        oldEnd: UInt32,
        newEnd: UInt32,
        rebuild: (S, UInt32, UInt32) -> S
    ) -> [S] {
        let delta = Int64(newEnd) - Int64(oldEnd)
        return spans.compactMap { span in
            if span.endByte <= start {
                return span
            }
            guard span.startByte >= oldEnd else {
                return nil
            }
            return rebuild(span, moved(span.startByte, by: delta), moved(span.endByte, by: delta))
        }
    }

    private static func moved(_ value: UInt32, by delta: Int64) -> UInt32 {
        UInt32(Int64(value) + delta)
    }
}
