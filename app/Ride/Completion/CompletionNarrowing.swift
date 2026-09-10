import Foundation

enum CompletionNarrowing {
    static func filter<T>(_ items: [T], prefix: String, name: (T) -> String) -> [T] {
        guard !prefix.isEmpty else {
            return items
        }
        let wanted = prefix.lowercased()
        return items.filter { matches(name($0), lowercased: wanted) }
    }

    static func matches(_ name: String, prefix: String) -> Bool {
        matches(name, lowercased: prefix.lowercased())
    }

    static func selection<T>(in items: [T], previous: String?, name: (T) -> String) -> Int {
        guard let previous, let index = items.firstIndex(where: { name($0) == previous }) else {
            return 0
        }
        return index
    }

    static func hump(_ name: String) -> String {
        var out = ""
        var previous: Character = " "
        for c in name {
            let starts = out.isEmpty || previous == "_" || c.isUppercase
            if starts, c.isLetter || c.isNumber {
                out.append(contentsOf: c.lowercased())
            }
            previous = c
        }
        return out
    }

    private static func matches(_ name: String, lowercased wanted: String) -> Bool {
        if wanted.isEmpty || name.lowercased().hasPrefix(wanted) {
            return true
        }
        return hump(name).hasPrefix(wanted)
    }
}
