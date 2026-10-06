import SwiftUI

struct GitCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Git") {
            Toggle("Changes", isOn: Binding(get: { menu.showGit }, set: { _ in state.toggleGit() }))
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!menu.hasWorkspace)
            Button("Commit…") { state.showGitCommit() }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(!menu.hasRepo)
            Button("Push") { state.gitPush() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(!menu.hasRepo)
            Button("Pull") { state.gitPull() }
                .disabled(!menu.hasRepo)
            Button("Fetch") { state.gitFetch() }
                .disabled(!menu.hasRepo)
            Divider()
            Button("New Branch…") { state.gitNewBranch() }
                .disabled(!menu.hasRepo)
            Button("Refresh Status") { state.refreshGit() }
                .disabled(!menu.hasWorkspace)
        }
    }
}
