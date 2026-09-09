import SwiftUI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct OverlayCard<Content: View>: View {
    @ObservedObject private var ts = ThemeStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let width: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: width)
            .background {
                ZStack {
                    VisualEffect()
                    ts.ui.bgOverlay.opacity(0.78)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .stroke(ts.ui.border, lineWidth: Tokens.Size.hairline)
            )
            .shadow(color: .black.opacity(Tokens.Shadow.overlay.opacity), radius: Tokens.Shadow.overlay.radius, y: Tokens.Shadow.overlay.y)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.98)
            .onAppear {
                withAnimation(.easeOut(duration: OverlayPanel.appearDuration)) {
                    appeared = true
                }
            }
    }
}

struct OverlayBackdrop: View {
    let dismiss: () -> Void

    var body: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .onTapGesture(perform: dismiss)
    }
}
