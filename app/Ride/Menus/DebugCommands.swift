import SwiftUI

struct DebugCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Debug") {
            ForEach(Array(DebugAction.groups.enumerated()), id: \.offset) { _, group in
                ForEach(group) { action in
                    Button(action.title) { action.perform(state) }
                        .keyboardShortcut(action.shortcut)
                        .disabled(!action.isEnabled(menu.debugGates))
                }
                Divider()
            }
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
