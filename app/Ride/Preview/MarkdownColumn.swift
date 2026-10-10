import SwiftUI

struct MarkdownColumn: View {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool
    @EnvironmentObject private var state: AppState
    @ObservedObject private var themes = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if focused, state.showFind, document.showHtmlSource {
                FindBar()
            }
            PanelHeader(icon: "doc.richtext", title: document.displayName, badges: [badge]) {
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
                revision: "\(document.htmlGeneration)|\(themes.theme.name)",
                page: { Self.page(document.text, themes.theme) },
                renderSibling: { Self.sibling($0, $1, themes.theme) }
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
        document.showHtmlSource ? "Show Rendered Markdown" : "Show Markdown Source"
    }

    private static func page(_ text: String, _ theme: Theme) -> String {
        let body = RideEngineClient.shared.engine?.renderMarkdown(text: text) ?? ""
        return PreviewTemplate.document(theme, body: body)
    }

    private static func sibling(_ name: String, _ data: Data, _ theme: Theme) -> String? {
        guard MarkdownPage.matches(URL(fileURLWithPath: name)),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return page(text, theme)
    }
}
