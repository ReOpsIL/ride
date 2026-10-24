import SwiftUI

struct RenderedColumn: View {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool
    let icon: String
    let sourceHelp: String
    let renderedHelp: String
    let revision: String
    let page: () -> String
    var renderSibling: HtmlRender?
    @EnvironmentObject private var state: AppState
    @ObservedObject private var themes = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if focused, state.showFind, document.showHtmlSource {
                FindBar()
            }
            PanelHeader(icon: icon, title: document.displayName, badges: [badge]) {
                IconButton(symbol: symbol, help: help) {
                    state.paneFocused(paneID)
                    document.showHtmlSource.toggle()
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themes.editorBackground)
    }

    @ViewBuilder
    private var content: some View {
        if document.showHtmlSource {
            EditorPane(document: document, state: state, paneID: paneID, focused: focused)
                .id(document.id)
        } else {
            HtmlWebView(
                document: document,
                paneID: paneID,
                focused: focused,
                revision: revision,
                page: page,
                renderSibling: renderSibling
            ) {
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
        document.showHtmlSource ? sourceHelp : renderedHelp
    }
}
