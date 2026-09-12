import SwiftTerm
import SwiftUI

struct TerminalTabView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        session.terminal
    }

    func updateNSView(_ view: LocalProcessTerminalView, context: Context) {
        view.needsDisplay = true
    }
}
