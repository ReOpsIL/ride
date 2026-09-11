import Foundation

enum Split: Equatable {
    case single
    case horizontal(ratio: Double)
}

enum SplitSide: Equatable {
    case left
    case right
}

struct SplitLayout: Equatable {
    static let minRatio = 0.2
    static let maxRatio = 0.8
    static let defaultRatio = 0.5

    private(set) var split: Split
    private(set) var focused: SplitSide

    init(split: Split = .single, focused: SplitSide = .left) {
        switch split {
        case .single:
            self.split = .single
            self.focused = .left
        case .horizontal(let ratio):
            self.split = .horizontal(ratio: Self.clamp(ratio))
            self.focused = focused
        }
    }

    var isSplit: Bool {
        if case .horizontal = split {
            return true
        }
        return false
    }

    var ratio: Double {
        switch split {
        case .single:
            return 1
        case .horizontal(let ratio):
            return ratio
        }
    }

    mutating func toggle() {
        if isSplit {
            closeRight()
        } else {
            split = .horizontal(ratio: Self.defaultRatio)
            focused = .right
        }
    }

    mutating func closeRight() {
        split = .single
        focused = .left
    }

    mutating func setRatio(_ value: Double) {
        guard isSplit else {
            return
        }
        split = .horizontal(ratio: Self.clamp(value))
    }

    mutating func focus(_ side: SplitSide) {
        focused = isSplit ? side : .left
    }

    static func clamp(_ value: Double) -> Double {
        min(maxRatio, max(minRatio, value))
    }

    static func restore(_ state: SplitState?) -> SplitLayout {
        guard let state else {
            return SplitLayout()
        }
        let side: SplitSide = state.focused == 1 ? .right : .left
        return SplitLayout(split: .horizontal(ratio: state.ratio), focused: side)
    }
}
