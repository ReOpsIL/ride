import SwiftUI

struct HtmlColumn: View {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool

    var body: some View {
        RenderedColumn(
            document: document,
            paneID: paneID,
            focused: focused,
            icon: "globe",
            sourceHelp: "Show Rendered HTML",
            renderedHelp: "Show HTML Source",
            revision: "\(document.htmlGeneration)",
            page: { document.text }
        )
    }
}
