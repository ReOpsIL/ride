import SwiftUI

struct SizeReporter: ViewModifier {
    enum Axis {
        case width
        case height
    }

    let axis: Axis
    let onChange: (Double) -> Void

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: axis == .width ? proxy.size.width : proxy.size.height) { _, value in
                        if value > 0 {
                            onChange(value)
                        }
                    }
            }
        )
    }
}

extension View {
    func reportSize(_ axis: SizeReporter.Axis, _ onChange: @escaping (Double) -> Void) -> some View {
        modifier(SizeReporter(axis: axis, onChange: onChange))
    }
}
