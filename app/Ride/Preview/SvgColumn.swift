import SwiftUI

struct SvgColumn: View {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool
    @ObservedObject private var themes = ThemeStore.shared

    var body: some View {
        RenderedColumn(
            document: document,
            paneID: paneID,
            focused: focused,
            icon: "photo",
            sourceHelp: "Show Rendered SVG",
            renderedHelp: "Show SVG Source",
            revision: "\(document.htmlGeneration)|\(themes.theme.name)",
            page: { Self.page(document.text, themes.theme) },
            renderSibling: { Self.sibling($0, $1, themes.theme) }
        )
    }

    private static func page(_ text: String, _ theme: Theme) -> String {
        SvgPage.document(text, background: PreviewTemplate.hex(theme.editor.background), dark: theme.isDark)
    }

    private static func sibling(_ name: String, _ data: Data, _ theme: Theme) -> String? {
        guard SvgPage.matches(URL(fileURLWithPath: name)),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return page(text, theme)
    }
}
