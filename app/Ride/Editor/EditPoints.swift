import Foundation

struct TextPoint: Equatable {
    var byte = 0
    var row: UInt32 = 0
    var column: UInt32 = 0

    func advanced(by unit: UInt16) -> TextPoint {
        let width = Self.utf8Width(unit)
        if unit == 10 {
            return TextPoint(byte: byte + width, row: row + 1, column: 0)
        }
        return TextPoint(byte: byte + width, row: row, column: column + UInt32(width))
    }

    private static func utf8Width(_ unit: UInt16) -> Int {
        switch unit {
        case 0 ..< 0x80: return 1
        case 0x80 ..< 0x800: return 2
        case 0xD800 ..< 0xDC00: return 4
        case 0xDC00 ..< 0xE000: return 0
        default: return 3
        }
    }
}

struct EditPoints: Equatable {
    let start: TextPoint
    let oldEnd: TextPoint
    let newEnd: TextPoint

    init(before: String, utf16Range: NSRange, inserted: String) {
        let (start, oldEnd) = Self.scan(before, first: utf16Range.location, second: NSMaxRange(utf16Range))
        self.start = start
        self.oldEnd = oldEnd
        newEnd = inserted.utf16.reduce(start) { $0.advanced(by: $1) }
    }

    private static func scan(_ text: String, first: Int, second: Int) -> (TextPoint, TextPoint) {
        var cursor = TextPoint()
        var marked: TextPoint?
        for (index, unit) in text.utf16.enumerated() {
            if index == first {
                marked = cursor
            }
            if index == second {
                return (marked ?? cursor, cursor)
            }
            cursor = cursor.advanced(by: unit)
        }
        return (marked ?? cursor, cursor)
    }
}
