import SwiftUI

struct TerminalPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var store: TerminalStore

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "terminal", title: "Terminal", badges: badges) {
                IconButton(symbol: "plus", help: "New Terminal") {
                    state.newTerminal()
                }
                IconButton(symbol: "xmark", help: "Hide Terminal", size: 9) {
                    state.showTerminal = false
                }
            }
            if !store.tabs.isEmpty {
                TerminalTabStrip(
                    tabs: store.tabs,
                    select: { state.selectTerminal($0) },
                    close: { store.close($0) }
                )
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.editorBackground)
    }

    @ViewBuilder
    private var content: some View {
        if let id = store.tabs.selected, let session = store.session(id) {
            TerminalTabView(session: session)
                .id(id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Button("New Terminal") { state.newTerminal() }
                .buttonStyle(.plain)
                .font(Tokens.ui(12, weight: .semibold))
                .foregroundStyle(ts.ui.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var badges: [PanelBadge] {
        guard store.tabs.count > 1 else {
            return []
        }
        return [PanelBadge(id: "count", text: "\(store.tabs.count) tabs", tint: nil)]
    }
}
