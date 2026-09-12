import Foundation

struct SplitState: Codable, Equatable {
    var panes: [[String]]
    var focused: Int
    var ratio: Double

    init(panes: [[String]] = [], focused: Int = 0, ratio: Double) {
        self.panes = panes
        self.focused = focused
        self.ratio = ratio
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        panes = try c.decodeIfPresent([[String]].self, forKey: .panes) ?? []
        focused = try c.decodeIfPresent(Int.self, forKey: .focused) ?? 0
        ratio = try c.decodeIfPresent(Double.self, forKey: .ratio) ?? 0.5
    }

    static func from(ratio: Double, panes: [Pane], focused: UUID, pathOf: (UUID) -> String?) -> SplitState {
        SplitState(
            panes: panes.map { pane in pane.tabs.compactMap(pathOf) },
            focused: panes.firstIndex { $0.id == focused } ?? 0,
            ratio: ratio
        )
    }

    func tabs(ids: [String: UUID], leftover: [UUID]) -> [[UUID]] {
        var seen = Set<String>()
        var tabs = panes.map { pane in
            pane.filter { seen.insert($0).inserted }.compactMap { ids[$0] }
        }
        if tabs.count < 2 {
            tabs += Array(repeating: [], count: 2 - tabs.count)
        }
        tabs = Array(tabs.prefix(2))
        let placed = Set(tabs.flatMap { $0 })
        tabs[0].append(contentsOf: leftover.filter { !placed.contains($0) })
        return tabs
    }
}
