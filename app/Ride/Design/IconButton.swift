import SwiftUI

struct IconButton: View {
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false
    let symbol: String
    let help: String
    var size: CGFloat = Tokens.Size.iconS
    var tint: Color?
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint ?? (active ? ts.ui.accent : ts.ui.textSecondary))
                .frame(width: 22, height: 22)
                .background(hovering ? ts.ui.bgHover : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
