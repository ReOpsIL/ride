import Foundation

enum DiagnosticRange {
    static func nsRange(in text: String, byteStart: UInt32, byteEnd: UInt32) -> NSRange? {
        nsRange(map: Utf16Map(text), length: (text as NSString).length, byteStart: byteStart, byteEnd: byteEnd)
    }

    static func nsRange(map: Utf16Map, length: Int, byteStart: UInt32, byteEnd: UInt32) -> NSRange? {
        guard length > 0 else {
            return nil
        }
        var range = map.nsRange(startByte: byteStart, endByte: max(byteEnd, byteStart))
        guard range.location < length else {
            return nil
        }
        if range.length == 0 {
            range.length = 1
        }
        range.length = min(range.length, length - range.location)
        return range
    }
}
