import Foundation

enum Utf16 {
    static func utf8Offset(in text: String, utf16: Int) -> Int {
        let u16 = text.utf16
        let clamped = min(max(utf16, 0), u16.count)
        let i = u16.index(u16.startIndex, offsetBy: clamped)
        guard let si = String.Index(i, within: text) else {
            return text.utf8.count
        }
        return text.utf8.distance(from: text.startIndex, to: si)
    }

    static func utf16Offset(in text: String, utf8: Int) -> Int {
        let u8 = text.utf8
        let clamped = min(max(utf8, 0), u8.count)
        let i = u8.index(u8.startIndex, offsetBy: clamped)
        guard let si = String.Index(i, within: text) else {
            return text.utf16.count
        }
        return text.utf16.distance(from: text.startIndex, to: si)
    }

    static func nsRange(in text: String, startByte: UInt32, endByte: UInt32) -> NSRange {
        let start = utf16Offset(in: text, utf8: Int(startByte))
        let end = utf16Offset(in: text, utf8: Int(endByte))
        return NSRange(location: start, length: max(0, end - start))
    }

    static func point(in text: String, utf8: Int) -> (UInt32, UInt32) {
        var row: UInt32 = 0
        var lineStart = 0
        var i = 0
        for c in text.utf8 {
            if i >= utf8 {
                break
            }
            if c == 10 {
                row += 1
                lineStart = i + 1
            }
            i += 1
        }
        return (row, UInt32(max(0, utf8 - lineStart)))
    }
}
