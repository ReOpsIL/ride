import SwiftUI

struct PanelBadge: Identifiable {
    let id: String
    let text: String
    let tint: Color?
}

struct PanelHeader<Actions: View>: View {
    @ObservedObject private var ts = ThemeStore.shared
    let icon: String
    let title: String
    var badges: [PanelBadge] = []
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: icon)
                .font(.system(size: Tokens.Size.iconS, weight: .semibold))
                .foregroundStyle(ts.ui.textSecondary)
            Text(title)
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            ForEach(badges) { badge in
                Text(badge.text)
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(badge.tint ?? ts.ui.textSecondary)
                    .padding(.horizontal, Tokens.Space.s)
                    .padding(.vertical, 1)
                    .background(ts.ui.bgHover, in: Capsule())
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.panelHeader)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .bottom) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }
}
