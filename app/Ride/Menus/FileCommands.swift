import SwiftUI

struct FileCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File…") { state.newFile() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!menu.hasWorkspace)
            Button("New Buffer") { state.newUntitled() }
                .keyboardShortcut("n", modifiers: [.command, .option])
            Button("New Folder…") { state.newFolder() }
                .disabled(!menu.hasWorkspace)
            Divider()
            Button("Open…") { state.openAnything() }
                .keyboardShortcut("o", modifiers: .command)
            if !menu.recent.isEmpty {
                Menu("Open Recent") {
                    ForEach(menu.recent, id: \.self) { url in
                        Button(url.lastPathComponent) { state.open(url) }
                    }
                }
            }
            Button("Close Workspace") { state.closeWorkspace() }
                .disabled(!menu.hasWorkspace)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { state.saveActive() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!menu.hasEditor)
            Button("Save As…") { state.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!menu.hasEditor)
            Button("Save All") { state.saveAll() }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(!menu.hasEditor)
            Button("Revert to Saved") { state.revertToSaved() }
                .disabled(!menu.hasEditor)
        }
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Close Editor") {
                if let id = state.activeID {
                    state.closeBuffer(id)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(!menu.hasEditor)
            Button("Close All") { state.closeAll() }
                .keyboardShortcut("w", modifiers: [.command, .option])
                .disabled(!menu.hasEditor)
            Button("Close Others") { state.closeOthers() }
                .disabled(!menu.hasEditor)
            Divider()
            Button("Reindex") { state.reindex() }
                .disabled(!menu.hasWorkspace)
        }
    }
}
