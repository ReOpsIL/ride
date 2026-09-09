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
            .fill(active ? ts.ui.accent : Color(nsColor: DividerGrip.fill))
            .frame(
                width: axis == .horizontal ? DividerGrip.thickness : DividerGrip.length,
                height: axis == .horizontal ? DividerGrip.length : DividerGrip.thickness
            )
            .allowsHitTesting(false)
    }
}
