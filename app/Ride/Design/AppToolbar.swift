import SwiftUI

struct AppToolbar: ToolbarContent {
    let state: AppState
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
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .principal)
        } else {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
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
