import SwiftUI

struct DebugCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Debug") {
            Button("Debug") { state.startDebug() }
                .keyboardShortcut("r", modifiers: [.control, .command])
                .disabled(!menu.canDebug || menu.isDebugging)
            Button("Continue") { state.debugCommand(.continue) }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(!menu.isDebugStopped)
            Divider()
            Button("Step Over") { state.debugCommand(.next) }
                .keyboardShortcut(FunctionKeys.f8, modifiers: [])
                .disabled(!menu.isDebugStopped)
            Button("Step Into") { state.debugCommand(.stepIn) }
                .keyboardShortcut(FunctionKeys.f7, modifiers: [])
                .disabled(!menu.isDebugStopped)
            Button("Step Out") { state.debugCommand(.stepOut) }
                .keyboardShortcut(FunctionKeys.f8, modifiers: .shift)
                .disabled(!menu.isDebugStopped)
            Divider()
            Button("Pause") { state.debugCommand(.pause) }
                .disabled(!menu.isDebugRunning)
            Button("Stop") { state.stopDebug() }
                .keyboardShortcut(FunctionKeys.f2, modifiers: .command)
                .disabled(!menu.isDebugging)
            Divider()
            Button("Toggle Breakpoint") { state.toggleBreakpointAtCaret() }
                .keyboardShortcut(FunctionKeys.f8, modifiers: .command)
                .disabled(!menu.hasEditor)
            Divider()
            Toggle("Debug Panel", isOn: Binding(get: { menu.showDebugPanel }, set: { _ in state.toggleDebugPanel() }))
                .keyboardShortcut("3", modifiers: .command)
            Button("Evaluate Expression…") { state.showEvaluateSheet() }
                .keyboardShortcut(FunctionKeys.f8, modifiers: .option)
                .disabled(!menu.isDebugStopped)
            Divider()
            ForEach(menu.debugFilters) { filter in
                Toggle(filter.label, isOn: Binding(get: { filter.enabled }, set: { _ in state.toggleExceptionFilter(id: filter.id) }))
            }
        }
    }
}
