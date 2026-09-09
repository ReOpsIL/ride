import SwiftUI

struct StatusSegment: View {
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false
    var icon: String?
    let text: String
    var tint: Color?
    var help: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(Tokens.ui(11))
                .lineLimit(1)
        }
        .foregroundStyle(tint ?? ts.ui.textSecondary)
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: 18)
        .background(hovering && action != nil ? ts.ui.bgHover : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            action?()
        }
        .help(help ?? text)
    }
}
