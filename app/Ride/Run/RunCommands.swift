import SwiftUI

struct RunCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Run") {
            Button("Build") { state.runAction(.build) }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(!menu.canBuild)
            Button("Run") { state.runAction(.run) }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!menu.canRunTarget)
            Button("Run Tests") { state.runAction(.test) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!menu.canRunTests)
            Divider()
            Button("Run File") { state.runFile() }
                .keyboardShortcut("r", modifiers: [.control, .shift])
                .disabled(!menu.canRunFile)
            Button("Recompile File") { state.recompileFile() }
                .keyboardShortcut(FunctionKeys.f9, modifiers: [.command, .shift])
                .disabled(!menu.canRecompileFile)
            Divider()
            Button("Stop") { state.stopRun() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!menu.isRunning)
            Divider()
            Button("Edit Configurations…") { state.editRunConfig() }
                .disabled(!menu.canBuild)
        }
    }
}
