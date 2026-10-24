import SwiftUI

struct MarkdownColumn: View {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool
    @ObservedObject private var themes = ThemeStore.shared

    var body: some View {
        RenderedColumn(
            document: document,
            paneID: paneID,
            focused: focused,
            icon: "doc.richtext",
            sourceHelp: "Show Rendered Markdown",
            renderedHelp: "Show Markdown Source",
            revision: "\(document.htmlGeneration)|\(themes.theme.name)",
            page: { Self.page(document.text, themes.theme) },
            renderSibling: { Self.sibling($0, $1, themes.theme) }
        )
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
