import SwiftUI

struct AIChatPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: AIChatStore
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "sparkles", title: store.current?.title ?? "AI Chat", badges: badges) {
                AIChatThreadMenu(store: store)
                IconButton(symbol: "square.and.pencil", help: "New Chat") {
                    store.newThread()
                    store.focusInput = true
                }
                IconButton(symbol: "xmark", help: "Hide AI Chat", size: 9) {
                    AIAssistant.shared.showPanel = false
                }
            }
            AIChatTranscript(
                thread: store.current,
                themeName: ts.theme.name,
                insert: { state.insertAtCaret($0) },
                open: { state.openChatLocation(path: $0, line: $1) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ts.ui.border.frame(height: Tokens.Size.hairline)
            AIChatComposer(store: store)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.editorBackground)
    }

    private var badges: [PanelBadge] {
        store.streaming ? [PanelBadge(id: "busy", text: "answering…", tint: ts.ui.accent)] : []
    }
}

struct AIChatThreadMenu: View {
    @ObservedObject var store: AIChatStore

    var body: some View {
        Menu {
            ForEach(store.threads) { thread in
                Button(thread.title) { store.select(thread.id) }
            }
            if let current = store.current {
                Divider()
                Button("Delete This Chat") { store.delete(current.id) }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(store.threads.isEmpty)
        .help("Chat history")
    }
}
