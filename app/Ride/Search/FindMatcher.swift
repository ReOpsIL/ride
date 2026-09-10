import Foundation

struct FindOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
    var regex = false

    static let defaults = FindOptions()
}

enum FindMatcher {
    static func matches(in text: String, query: String, options: FindOptions) -> [NSRange] {
        guard !query.isEmpty, let expression = expression(query, options: options) else {
            return []
        }
        let ns = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: ns.length)).map(\.range)
    }

    static func next(in text: String, query: String, options: FindOptions, from origin: Int, backwards: Bool) -> NSRange? {
        let all = matches(in: text, query: query, options: options)
        guard !all.isEmpty else {
            return nil
        }
        if backwards {
            return all.last(where: { NSMaxRange($0) <= origin }) ?? all.last
        }
        return all.first(where: { $0.location >= origin }) ?? all.first
    }

    static func replacement(_ template: String, options: FindOptions) -> String {
        options.regex ? template : NSRegularExpression.escapedTemplate(for: template)
    }

    static func expression(_ query: String, options: FindOptions) -> NSRegularExpression? {
        var pattern = options.regex ? query : NSRegularExpression.escapedPattern(for: query)
        if options.wholeWord {
            pattern = "\\b(?:" + pattern + ")\\b"
        }
        var flags: NSRegularExpression.Options = []
        if !options.caseSensitive {
            flags.insert(.caseInsensitive)
        }
        return try? NSRegularExpression(pattern: pattern, options: flags)
    }
}
