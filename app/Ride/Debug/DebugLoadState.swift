import Foundation

struct DebugLoadState: Equatable {
    private(set) var generation = 0
    private var inFlight: Set<String> = []

    @discardableResult
    mutating func invalidate() -> Int {
        generation += 1
        inFlight = []
        return generation
    }

    func isCurrent(_ value: Int) -> Bool {
        value == generation
    }

    func isInFlight(_ key: String) -> Bool {
        inFlight.contains(key)
    }

    var pending: Int {
        inFlight.count
    }

    mutating func begin(_ key: String) -> Int? {
        guard !inFlight.contains(key) else {
            return nil
        }
        inFlight.insert(key)
        return generation
    }

    mutating func finish(_ key: String, generation value: Int) -> Bool {
        guard value == generation else {
            return false
        }
        inFlight.remove(key)
        return true
    }
}
