import Foundation

enum DiagnosticRange {
    static func nsRange(in text: String, byteStart: UInt32, byteEnd: UInt32) -> NSRange? {
        let length = (text as NSString).length
        guard length > 0 else {
            return nil
        }
        var range = Utf16.nsRange(in: text, startByte: byteStart, endByte: max(byteEnd, byteStart))
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
