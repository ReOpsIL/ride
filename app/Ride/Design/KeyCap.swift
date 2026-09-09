import SwiftUI

struct KeyCap: View {
    @ObservedObject private var ts = ThemeStore.shared
    let key: String
    var size: CGFloat = 10

    var body: some View {
        Text(key)
            .font(Tokens.ui(size, weight: .semibold))
            .foregroundStyle(ts.ui.textSecondary)
            .padding(.horizontal, Tokens.Space.xs + 1)
            .padding(.vertical, 1)
            .background(ts.ui.bgHover, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.s)
                    .stroke(ts.ui.border, lineWidth: Tokens.Size.hairline)
            )
    }
}
