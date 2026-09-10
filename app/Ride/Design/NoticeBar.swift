import SwiftUI

struct NoticeBar: View {
    @ObservedObject private var ts = ThemeStore.shared
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ts.ui.accent)
            Text(text)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            IconButton(symbol: "xmark", help: "Dismiss", size: 9, action: dismiss)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(minHeight: 30)
        .frame(maxWidth: .infinity)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .bottom) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }
}
