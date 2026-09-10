import Foundation

enum CompletionTrigger: Equatable {
    case identifier
    case trigger
}

enum CompletionTriggerGate {
    static func trigger(language: BufferLanguage, line: String, inserted: String) -> CompletionTrigger? {
        guard language.hasCompletions, inserted.count == 1, let c = inserted.first else {
            return nil
        }
        if isIdentifierChar(c) {
            if c.isNumber, !continuesIdentifier(line) {
                return nil
            }
            return .identifier
        }
        switch language {
        case .rust: return rust(line) ? .trigger : nil
        case .c, .cpp: return cFamily(line) ? .trigger : nil
        case .toml, .make, .cmake, .markdown, .plain: return nil
        }
    }

    static func isIdentifierChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }

    static func rust(_ line: String) -> Bool {
        if line.hasSuffix("::") || line.hasSuffix("#") {
            return true
        }
        if line.hasSuffix(".") {
            return !line.hasSuffix("..")
        }
        if line.hasSuffix("(") {
            return line.hasSuffix("derive(")
        }
        if line.hasSuffix(" ") {
            return lastWord(line) == "use"
        }
        return false
    }

    static func cFamily(_ line: String) -> Bool {
        if line.hasSuffix("->") || line.hasSuffix("::") {
            return true
        }
        if line.hasSuffix(".") {
            return !line.hasSuffix("..")
        }
        if line.hasSuffix("#") {
            return line.dropLast().allSatisfy(\.isWhitespace)
        }
        guard let argument = includeArgument(line), let open = argument.first, open == "<" || open == "\"" else {
            return false
        }
        if argument.count == 1 {
            return true
        }
        let inner = argument.dropFirst()
        return inner.hasSuffix("/") && !inner.contains(where: { $0 == ">" || $0 == "\"" })
    }

    private static func continuesIdentifier(_ line: String) -> Bool {
        guard let previous = line.dropLast().last else {
            return false
        }
        return isIdentifierChar(previous)
    }

    private static func lastWord(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return String(trimmed.reversed().prefix(while: isIdentifierChar).reversed())
    }

    private static func includeArgument(_ line: String) -> Substring? {
        var rest = Substring(line).drop(while: \.isWhitespace)
        guard rest.first == "#" else {
            return nil
        }
        rest = rest.dropFirst().drop(while: \.isWhitespace)
        guard rest.hasPrefix("include") else {
            return nil
        }
        rest = rest.dropFirst("include".count)
        guard let next = rest.first, !isIdentifierChar(next) else {
            return nil
        }
        return rest.drop(while: \.isWhitespace)
    }
}
