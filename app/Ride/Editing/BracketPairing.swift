import Foundation

enum PairAction: Equatable {
    case insertPair(String)
    case typeOver
    case wrap(open: String, close: String)
    case none
}

struct BracketMatch: Equatable {
    let open: Int
    let close: Int
}

enum BracketPairing {
    static let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
    static let closers: Set<String> = [")", "]", "}", "\"", "'"]
    static let pairableFollowers: Set<String> = [")", "]", "}", ";", ",", " ", "\t", "\n"]
    static let matchers: [(open: String, close: String)] = [
        ("(", ")"), ("[", "]"), ("{", "}"), ("<", ">"),
    ]

    static func onType(_ typed: String, text: String, selection: NSRange, language: BufferLanguage) -> PairAction {
        if typed == "'", language == .rust {
            return .none
        }
        let source = text as NSString
        let next = character(source, at: selection.upperBound)
        if selection.length == 0, closers.contains(typed), next == typed {
            return .typeOver
        }
        guard let close = pairs[typed] else {
            return .none
        }
        if selection.length > 0 {
            return .wrap(open: typed, close: close)
        }
        if isQuote(typed), let previous = character(source, at: selection.location - 1), blocksQuote(previous) {
            return .none
        }
        guard next == nil || pairableFollowers.contains(next ?? "") else {
            return .none
        }
        return .insertPair(close)
    }

    static func deletesPair(_ text: String, caret: Int) -> Bool {
        let source = text as NSString
        guard let previous = character(source, at: caret - 1), let close = pairs[previous] else {
            return false
        }
        return character(source, at: caret) == close
    }

    static func pair(in text: String, caret: Int) -> BracketMatch? {
        let source = text as NSString
        let at = [caret, caret - 1].first { loc in
            character(source, at: loc).flatMap(matcher) != nil
        }
        guard let at, let ch = character(source, at: at), let match = matcher(ch) else {
            return nil
        }
        return scan(source, from: at, open: match.open, close: match.close, step: match.opens ? 1 : -1)
    }

    static func isQuote(_ typed: String) -> Bool {
        typed == "\"" || typed == "'"
    }

    private static func blocksQuote(_ previous: String) -> Bool {
        previous == "\\" || previous.utf16.first.map(LineOps.isWordUnit) == true
    }

    private static func character(_ text: NSString, at location: Int) -> String? {
        guard location >= 0, location < text.length else {
            return nil
        }
        return text.substring(with: NSRange(location: location, length: 1))
    }

    private static func matcher(_ ch: String) -> (open: String, close: String, opens: Bool)? {
        if let pair = matchers.first(where: { $0.open == ch }) {
            return (pair.open, pair.close, true)
        }
        if let pair = matchers.first(where: { $0.close == ch }) {
            return (pair.open, pair.close, false)
        }
        return nil
    }

    private static func scan(
        _ text: NSString,
        from start: Int,
        open: String,
        close: String,
        step: Int
    ) -> BracketMatch? {
        var depth = 0
        var i = start
        while i >= 0, i < text.length {
            let ch = text.substring(with: NSRange(location: i, length: 1))
            if ch == open {
                depth += step
            } else if ch == close {
                depth -= step
            }
            if depth == 0 {
                return BracketMatch(open: min(start, i), close: max(start, i))
            }
            i += step
        }
        return nil
    }
}
