import SwiftUI

struct SplitHandle: View {
    enum Axis {
        case horizontal
        case vertical
    }

    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false
    @State private var dragStart: Double?
    let axis: Axis
    @Binding var value: Double
    let range: ClosedRange<Double>
    var inverted = false

    var body: some View {
        Rectangle()
            .fill(hovering ? ts.ui.accent.opacity(0.6) : ts.ui.border)
            .frame(
                width: axis == .horizontal ? Tokens.Size.hairline : nil,
                height: axis == .vertical ? Tokens.Size.hairline : nil
            )
            .overlay {
                Color.clear
                    .frame(
                        width: axis == .horizontal ? 7 : nil,
                        height: axis == .vertical ? 7 : nil
                    )
                    .contentShape(Rectangle())
                    .onHover { inside in
                        hovering = inside
                        if inside {
                            (axis == .horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(drag)
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { g in
                if dragStart == nil {
                    dragStart = value
                }
                let delta = axis == .horizontal ? g.translation.width : g.translation.height
                let next = (dragStart ?? value) + (inverted ? -delta : delta)
                value = min(max(next, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                dragStart = nil
            }
    }
}
