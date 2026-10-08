import SwiftUI

struct HtmlColumn: View {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if focused, state.showFind, document.showHtmlSource {
                FindBar()
            }
            PanelHeader(icon: "globe", title: document.displayName, badges: [badge]) {
                IconButton(symbol: symbol, help: help) {
                    state.paneFocused(paneID)
                    document.showHtmlSource.toggle()
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.editorBackground)
    }

    @ViewBuilder
    private var content: some View {
        if document.showHtmlSource {
            EditorPane(document: document, state: state, paneID: paneID, focused: focused)
                .id(document.id)
        } else {
            HtmlWebView(document: document, focused: focused) {
                state.paneFocused(paneID)
            }
            .id(document.fileURL)
        }
    }

    private var badge: PanelBadge {
        PanelBadge(id: "mode", text: document.showHtmlSource ? "Source" : "Rendered", tint: nil)
    }

    private var symbol: String {
        document.showHtmlSource ? "eye" : "chevron.left.forwardslash.chevron.right"
    }

    private var help: String {
        document.showHtmlSource ? "Show Rendered HTML" : "Show HTML Source"
    }
}
