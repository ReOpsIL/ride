import Foundation

struct PopupSearch: Equatable {
    private(set) var query = ""
    private(set) var isActive = false

    var terms: [String] {
        query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
    }

    mutating func begin() {
        isActive = true
    }

    mutating func end() {
        self = PopupSearch()
    }

    mutating func type(_ text: String) {
        isActive = true
        query += text
    }

    mutating func deleteBackward() {
        if !query.isEmpty {
            query.removeLast()
        }
    }

    func filter<T>(_ items: [T], fields: (T) -> [String]) -> [T] {
        let terms = terms
        guard !terms.isEmpty else {
            return items
        }
        var byName: [T] = []
        var byText: [T] = []
        for item in items {
            let texts = fields(item).map { $0.lowercased() }
            if let name = texts.first, terms.allSatisfy(name.contains) {
                byName.append(item)
            } else if terms.allSatisfy({ term in texts.contains { $0.contains(term) } }) {
                byText.append(item)
            }
        }
        return byName + byText
    }

    static func typed(_ characters: String) -> String? {
        guard !characters.isEmpty, characters.unicodeScalars.allSatisfy(isPrintable) else {
            return nil
        }
        return characters
    }

    private static func isPrintable(_ scalar: Unicode.Scalar) -> Bool {
        !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
    }
}
