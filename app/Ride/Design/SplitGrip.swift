import SwiftUI

struct SplitGrip: View {
    enum Axis {
        case horizontal
        case vertical
    }

    @ObservedObject private var ts = ThemeStore.shared
    let axis: Axis
    var active = false

    var body: some View {
        Capsule(style: .continuous)
            .fill(active ? ts.ui.accent : ts.ui.textTertiary.opacity(0.7))
            .frame(
                width: axis == .horizontal ? 3 : 28,
                height: axis == .horizontal ? 28 : 3
            )
            .allowsHitTesting(false)
    }
}
