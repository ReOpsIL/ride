import CoreGraphics

struct SplitDividerPlacement: Equatable {
    let index: Int
    let position: CGFloat

    static func divider(
        for pane: Int,
        extents: [CGFloat],
        divider: CGFloat,
        total: CGFloat,
        size: CGFloat,
        fromEnd: Bool
    ) -> SplitDividerPlacement? {
        guard extents.indices.contains(pane), extents.count > 1 else {
            return nil
        }
        guard fromEnd else {
            guard pane < extents.count - 1 else {
                return nil
            }
            let before = extents[..<pane].reduce(0, +) + divider * CGFloat(pane)
            return SplitDividerPlacement(index: pane, position: before + size)
        }
        guard pane > 0 else {
            return nil
        }
        let laterPanes = extents[(pane + 1)...]
        let after = laterPanes.reduce(0, +) + divider * CGFloat(laterPanes.count)
        return SplitDividerPlacement(index: pane - 1, position: max(total - after - size - divider, 0))
    }
}
