import SwiftUI

struct TerminalTabStrip: View {
    @ObservedObject private var ts = ThemeStore.shared
    let tabs: TerminalTabs
    let select: (UUID) -> Void
    let close: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.xxs) {
                ForEach(tabs.items) { item in
                    row(item)
                }
            }
            .padding(.horizontal, Tokens.Space.s)
        }
        .frame(height: Tokens.Size.sidebarRow + Tokens.Space.s)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .bottom) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }

    private func row(_ item: TerminalTabItem) -> some View {
        let active = tabs.selected == item.id
        return HStack(spacing: Tokens.Space.xs) {
            Text(item.title)
                .font(Tokens.ui(11, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? ts.ui.textPrimary : ts.ui.textSecondary)
                .lineLimit(1)
            IconButton(symbol: "xmark", help: "Close Terminal", size: 8) { close(item.id) }
        }
        .padding(.leading, Tokens.Space.m)
        .padding(.trailing, Tokens.Space.xs)
        .padding(.vertical, Tokens.Space.xxs)
        .background(active ? ts.ui.bgSelection : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .contentShape(Rectangle())
        .onTapGesture { select(item.id) }
    }
}
