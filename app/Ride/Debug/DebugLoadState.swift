import Foundation

struct DebugLoadToken: Equatable {
    let generation: Int
    let selection: Int?
}

struct DebugLoadState: Equatable {
    private(set) var generation = 0
    private(set) var selection = 0
    private var inFlight: [String: Bool] = [:]

    @discardableResult
    mutating func invalidate() -> Int {
        generation += 1
        inFlight = [:]
        return generation
    }

    mutating func select() {
        selection += 1
        inFlight = inFlight.filter { !$0.value }
    }

    func isCurrent(_ value: Int) -> Bool {
        value == generation
    }

    mutating func begin(_ key: String, scoped: Bool = true) -> DebugLoadToken? {
        guard inFlight[key] == nil else {
            return nil
        }
        inFlight[key] = scoped
        return DebugLoadToken(generation: generation, selection: scoped ? selection : nil)
    }

    mutating func finish(_ key: String, token: DebugLoadToken) -> Bool {
        guard token.generation == generation, token.selection.map({ $0 == selection }) ?? true else {
            return false
        }
        inFlight[key] = nil
        return true
    }
}
