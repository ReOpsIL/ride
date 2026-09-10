import Foundation

enum PairAction: Equatable {
    case insertPair(String)
    case typeOver
    case wrap(open: String, close: String)
    case none
}

enum BracketPairing {
    static let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
    static let closers: Set<String> = [")", "]", "}", "\"", "'"]
    static let pairableFollowers: Set<String> = [")", "]", "}", ";", ",", " ", "\t", "\n"]

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
}
