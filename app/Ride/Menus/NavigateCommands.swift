import SwiftUI

struct NavigateCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Open Quickly…") { state.toggleQuickOpen() }
                .keyboardShortcut("p", modifiers: .command)
            Button("Recent Files…") { state.toggleRecentFiles() }
                .keyboardShortcut("e", modifiers: .command)
            Divider()
            Button("Back") { state.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!menu.canGoBack)
            Button("Forward") { state.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!menu.canGoForward)
            Button("Last Edit Location") { state.goToLastEdit() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            Button("Go to Line…") { state.toggleGoToLine() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(!menu.hasEditor)
            Divider()
            Button("Go to Symbol in File…") { state.toggleSymbolInFile() }
                .keyboardShortcut("o", modifiers: [.command, .option])
            Button("Go to Symbol in Project…") { state.toggleSymbolPicker() }
                .keyboardShortcut("o", modifiers: [.command, .option, .shift])
            Button("Go to Definition") { state.goToDefinition() }
                .keyboardShortcut(FunctionKeys.f12, modifiers: [])
            Button("Switch Header / Source") { state.switchHeaderSource() }
                .keyboardShortcut(FunctionKeys.f10, modifiers: [])
            Divider()
            Button("Next Problem") { state.nextProblem(1) }
                .keyboardShortcut(FunctionKeys.f2, modifiers: [])
            Button("Previous Problem") { state.nextProblem(-1) }
                .keyboardShortcut(FunctionKeys.f2, modifiers: .shift)
            Button("Next Method") { state.nextMethod(1) }
                .keyboardShortcut(.downArrow, modifiers: .control)
            Button("Previous Method") { state.nextMethod(-1) }
                .keyboardShortcut(.upArrow, modifiers: .control)
            Button("Matching Brace") { EditorCommands.matchingBrace() }
                .keyboardShortcut("m", modifiers: .control)
        }
    }
}
