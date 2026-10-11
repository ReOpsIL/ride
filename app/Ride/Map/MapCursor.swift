import Foundation

struct MapCursor {
    let text: String
    var index: String.Index

    init(_ text: String) {
        self.text = text
        index = text.startIndex
    }

    var done: Bool { index >= text.endIndex }

    var char: Character? { done ? nil : text[index] }

    mutating func bump() {
        guard !done else { return }
        index = text.index(after: index)
    }

    func peek(_ offset: Int) -> Character? {
        var cursor = index
        for _ in 0..<offset {
            guard cursor < text.endIndex else { return nil }
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex else { return nil }
        return text[cursor]
    }

    mutating func skipTrivia() {
        while !done {
            if char == "/", peek(1) == "/" {
                while !done, char != "\n" { bump() }
                continue
            }
            if char == "/", peek(1) == "*" {
                bump()
                bump()
                while !done, !(char == "*" && peek(1) == "/") { bump() }
                bump()
                bump()
                continue
            }
            if char?.isWhitespace == true {
                bump()
                continue
            }
            return
        }
    }

    mutating func word() -> String? {
        skipTrivia()
        guard let char, char.isLetter || char == "_" else { return nil }
        let start = index
        bump()
        while let next = self.char, next.isLetter || next.isNumber || next == "_" { bump() }
        return String(text[start..<index])
    }

    func peekWord() -> String? {
        var copy = self
        return copy.word()
    }

    mutating func skipLiteral() -> Bool {
        if char == "b" || char == "c", peek(1) == "\"" || peek(1) == "'" {
            bump()
            return skipQuoted()
        }
        if skipRaw() { return true }
        if char == "\"" || char == "'" { return skipQuoted() }
        return false
    }

    mutating func header() -> String {
        skipTrivia()
        let start = index
        var paren = 0
        while !done {
            if skipLiteral() { continue }
            if char == "(" {
                paren += 1
                bump()
                continue
            }
            if char == ")" {
                paren = max(0, paren - 1)
                bump()
                continue
            }
            if paren == 0, char == "{" || char == ";" { break }
            bump()
        }
        return String(text[start..<index])
    }

    mutating func followingBody() -> String? {
        var paren = 0
        while !done {
            skipTrivia()
            if skipLiteral() { continue }
            if char == "(" {
                paren += 1
                bump()
                continue
            }
            if char == ")" {
                paren = max(0, paren - 1)
                bump()
                continue
            }
            if paren == 0, char == ";" {
                bump()
                return nil
            }
            if paren == 0, char == "{" { return captureBody() }
            bump()
        }
        return nil
    }

    mutating func captureBody() -> String? {
        guard char == "{" else { return nil }
        bump()
        let start = index
        var depth = 1
        while !done, depth > 0 {
            if skipLiteral() { continue }
            if char == "/", peek(1) == "/" || peek(1) == "*" {
                skipTrivia()
                continue
            }
            if char == "{" { depth += 1 }
            if char == "}" {
                depth -= 1
                if depth == 0 {
                    let body = String(text[start..<index])
                    bump()
                    return body
                }
            }
            bump()
        }
        return String(text[start..<index])
    }

    mutating func untilSemicolon() -> String {
        let start = index
        var depth = 0
        while !done {
            if skipLiteral() { continue }
            if char == "/", peek(1) == "/" || peek(1) == "*" {
                skipTrivia()
                continue
            }
            if char == "{" { depth += 1 }
            if char == "}" { depth = max(0, depth - 1) }
            if char == ";", depth == 0 {
                let body = String(text[start..<index])
                bump()
                return body
            }
            bump()
        }
        return String(text[start..<index])
    }

    private mutating func skipQuoted() -> Bool {
        guard let quote = char, quote == "\"" || quote == "'" else { return false }
        bump()
        while !done, char != quote {
            if char == "\\" { bump() }
            bump()
        }
        bump()
        return true
    }

    private mutating func skipRaw() -> Bool {
        let saved = index
        if char == "b" || char == "c" { bump() }
        guard char == "r" else {
            index = saved
            return false
        }
        bump()
        var hashes = 0
        while char == "#" {
            hashes += 1
            bump()
        }
        guard char == "\"" else {
            index = saved
            return false
        }
        bump()
        while !done {
            guard char == "\"" else {
                bump()
                continue
            }
            bump()
            var matched = 0
            while matched < hashes, char == "#" {
                matched += 1
                bump()
            }
            if matched == hashes { return true }
        }
        return true
    }
}
