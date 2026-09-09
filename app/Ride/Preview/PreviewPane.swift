import SwiftUI

struct PreviewPane: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "doc.richtext", title: "Preview") {
                IconButton(symbol: "xmark", help: "Close Preview") {
                    state.showPreview = false
                }
            }
            MarkdownPreview(model: state.preview)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ts.editorBackground)
        .overlay(alignment: .leading) {
            Rectangle().fill(ts.ui.border).frame(width: Tokens.Size.hairline)
        }
    }
}
