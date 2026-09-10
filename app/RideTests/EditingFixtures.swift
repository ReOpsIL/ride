import Foundation

enum Fixture {
    static func parse(_ fixture: String) -> (text: String, selection: NSRange) {
        var text = ""
        var start: Int?
        var end: Int?
        for unit in fixture.utf16 {
            switch unit {
            case 0x7C: start = text.utf16.count; end = start
            case 0x5B: start = text.utf16.count
            case 0x5D: end = text.utf16.count
            default: text.unicodeScalars.append(Unicode.Scalar(unit)!)
            }
        }
        let location = start ?? end ?? 0
        return (text, NSRange(location: location, length: max(0, (end ?? location) - location)))
    }

    static func render(_ text: String, _ selection: NSRange) -> String {
        let source = NSMutableString(string: text)
        if selection.length == 0 {
            source.insert("|", at: selection.location)
        } else {
            source.insert("]", at: selection.upperBound)
            source.insert("[", at: selection.location)
        }
        return source as String
    }

    static func apply(_ fixture: String, _ command: (String, NSRange) -> EditResult) -> String {
        let (text, selection) = parse(fixture)
        let result = command(text, selection)
        return render(EditResult.applying(result.changes, to: text), result.selection)
    }
}
