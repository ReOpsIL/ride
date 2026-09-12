import Foundation

struct BreakpointMark: Codable, Equatable {
    var line: UInt32
    var condition: String?
    var hitCondition: String?
    var verified: Bool

    init(line: UInt32, condition: String? = nil, hitCondition: String? = nil, verified: Bool = false) {
        self.line = line
        self.condition = condition
        self.hitCondition = hitCondition
        self.verified = verified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        line = try c.decodeIfPresent(UInt32.self, forKey: .line) ?? 1
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        hitCondition = try c.decodeIfPresent(String.self, forKey: .hitCondition)
        verified = try c.decodeIfPresent(Bool.self, forKey: .verified) ?? false
    }
}

struct Breakpoints: Codable, Equatable {
    private(set) var files: [String: [BreakpointMark]]

    init(files: [String: [BreakpointMark]] = [:]) {
        self.files = files.compactMapValues { marks in
            let cleaned = Self.normalized(marks)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let stored = (try? c.decode([String: [BreakpointMark]].self)) ?? [:]
        self.init(files: stored)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(files)
    }

    var isEmpty: Bool {
        files.isEmpty
    }

    var paths: [String] {
        files.keys.sorted()
    }

    func marks(path: String) -> [BreakpointMark] {
        files[path] ?? []
    }

    func lines(path: String) -> Set<UInt32> {
        Set(marks(path: path).map(\.line))
    }

    func mark(path: String, line: UInt32) -> BreakpointMark? {
        marks(path: path).first { $0.line == line }
    }

    @discardableResult
    mutating func toggle(path: String, line: UInt32) -> Bool {
        guard mark(path: path, line: line) == nil else {
            remove(path: path, line: line)
            return false
        }
        put(path: path, BreakpointMark(line: line))
        return true
    }

    mutating func remove(path: String, line: UInt32) {
        let kept = marks(path: path).filter { $0.line != line }
        files[path] = kept.isEmpty ? nil : kept
    }

    mutating func removeAll(path: String) {
        files[path] = nil
    }

    mutating func edit(path: String, line: UInt32, condition: String?, hitCondition: String?) {
        guard var found = mark(path: path, line: line) else {
            return
        }
        found.condition = Self.trimmed(condition)
        found.hitCondition = Self.trimmed(hitCondition)
        put(path: path, found)
    }

    mutating func verify(path: String, verified: Set<UInt32>) {
        let updated = marks(path: path).map { mark -> BreakpointMark in
            var next = mark
            next.verified = verified.contains(mark.line)
            return next
        }
        files[path] = updated.isEmpty ? nil : updated
    }

    private mutating func put(path: String, _ mark: BreakpointMark) {
        var marks = self.marks(path: path).filter { $0.line != mark.line }
        marks.append(mark)
        files[path] = Self.normalized(marks)
    }

    private static func normalized(_ marks: [BreakpointMark]) -> [BreakpointMark] {
        var seen = Set<UInt32>()
        return marks
            .filter { $0.line > 0 && seen.insert($0.line).inserted }
            .sorted { $0.line < $1.line }
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
