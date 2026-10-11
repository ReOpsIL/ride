import CoreGraphics

enum HoverReach {
    static let pad: CGFloat = 18

    static func contains(mouse: CGPoint, anchor: CGRect, card: CGRect) -> Bool {
        guard !anchor.isEmpty, !card.isEmpty else {
            return false
        }
        return anchor.union(card).insetBy(dx: -pad, dy: -pad).contains(mouse)
    }
}
