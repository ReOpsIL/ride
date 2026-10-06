import SwiftUI
import WebKit

struct AIChatTranscript: NSViewRepresentable {
    let thread: AIChatThread?
    let themeName: String
    let insert: (String) -> Void
    let open: (String, Int) -> Void

    final class Coordinator {
        let page = AIChatPage()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.page.view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let page = context.coordinator.page
        page.onInsert = insert
        page.onOpen = open
        page.show(thread)
    }
}
