import SwiftUI

struct AppToolbar: ToolbarContent {
    let state: AppState
    let title: String
    let hasWorkspace: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                state.showSidebar.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar (⌃⌘S)")
        }
        ToolbarItem(placement: .principal) {
            Text(title)
                .font(Tokens.ui(13, weight: .semibold))
                .lineLimit(1)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                state.runCheck()
            } label: {
                Image(systemName: "play.circle")
            }
            .disabled(!hasWorkspace)
            .help("Check (⌘B)")
            Button {
                state.toggleProblems()
            } label: {
                Image(systemName: "exclamationmark.triangle")
            }
            .help("Problems (⇧⌘M)")
            Button {
                state.toggleQuickOpen()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(!hasWorkspace)
            .help("Open Quickly (⌘P)")
        }
    }
}
