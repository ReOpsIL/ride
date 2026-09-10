import Foundation

extension LineOps {
    static func toggleCase(_ text: String, selection: NSRange) -> EditResult {
        let source = text as NSString
        let range = selection.length > 0 ? selection : wordRange(source, at: selection.location)
        guard range.length > 0 else {
            return .keep(selection)
        }
        let original = source.substring(with: range)
        let replacement = original == original.lowercased() ? original.uppercased() : original.lowercased()
        let change = TextChange(range: range, text: replacement)
        let width = replacement.utf16.count
        let kept = selection.length > 0 ? NSRange(location: range.location, length: width) : selection
        return EditResult(changes: [change], selection: kept)
    }

    static func wordRange(_ text: NSString, at location: Int) -> NSRange {
        var start = location
        while start > 0, isWordUnit(text.character(at: start - 1)) {
            start -= 1
        }
        var end = location
        while end < text.length, isWordUnit(text.character(at: end)) {
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }

    static func isWordUnit(_ unit: unichar) -> Bool {
        unit == 0x5F || CharacterSet.alphanumerics.contains(Unicode.Scalar(unit) ?? " ")
    }
}
