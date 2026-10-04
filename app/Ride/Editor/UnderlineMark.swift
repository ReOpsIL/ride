import AppKit

struct UnderlineMark {
    let range: NSRange
    let style: Int
    let color: NSColor

    func isApplied(in storage: NSTextStorage) -> Bool {
        guard range.length > 0, NSMaxRange(range) <= storage.length else {
            return false
        }
        var styleRun = NSRange()
        var colorRun = NSRange()
        let style = storage.attribute(.underlineStyle, at: range.location, longestEffectiveRange: &styleRun, in: range) as? Int
        let color = storage.attribute(.underlineColor, at: range.location, longestEffectiveRange: &colorRun, in: range) as? NSColor
        return style == self.style && color == self.color && styleRun == range && colorRun == range
    }

    func apply(to storage: NSTextStorage) {
        storage.addAttribute(.underlineStyle, value: style, range: range)
        storage.addAttribute(.underlineColor, value: color, range: range)
    }

    static func clear(_ range: NSRange, in storage: NSTextStorage) {
        storage.removeAttribute(.underlineStyle, range: range)
        storage.removeAttribute(.underlineColor, range: range)
    }
}
