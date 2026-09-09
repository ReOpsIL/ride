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
            .fill(active ? ts.ui.accent : ts.ui.textSecondary.opacity(0.75))
            .frame(
                width: axis == .horizontal ? 6 : 40,
                height: axis == .horizontal ? 40 : 6
            )
            .shadow(color: ts.ui.bgBase.opacity(0.6), radius: 1)
            .allowsHitTesting(false)
    }
}
