import SwiftUI

struct CodeCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Code") {
            Button("Comment Line") { EditorCommands.commentLine() }
                .keyboardShortcut("/", modifiers: .command)
            Button("Comment Block") { EditorCommands.commentBlock() }
                .keyboardShortcut("/", modifiers: [.command, .option])
            Divider()
            Button("Indent") { EditorCommands.indent() }
            Button("Unindent") { EditorCommands.unindent() }
            Button("Auto-Indent Lines") { EditorCommands.autoIndent() }
                .keyboardShortcut("i", modifiers: [.control, .option])
            Button("Reformat Document") { state.formatActive() }
                .keyboardShortcut("i", modifiers: [.control, .shift])
            Divider()
            Button("Surround With…") { EditorCommands.surroundWith() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button("Fold") { FoldController.shared.fold() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Unfold") { FoldController.shared.unfold() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("Fold All") { FoldController.shared.foldAll() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option, .shift])
            Button("Unfold All") { FoldController.shared.unfoldAll() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .shift])
            Divider()
            Button("Trigger Completion") { EditorCommands.triggerCompletion() }
                .keyboardShortcut(.space, modifiers: .control)
            Button("Cheat Sheet") { EditorCommands.toggleCheatSheet() }
                .keyboardShortcut(.space, modifiers: [.control, .shift])
            Button("Quick Documentation") { state.showQuickDocumentation() }
                .keyboardShortcut("j", modifiers: .control)
            Button("Signature Help") { state.showSignatureHelp() }
                .keyboardShortcut(.space, modifiers: [.command, .shift])
        }
        CommandMenu("Build") {
            Button("Check") { state.runCheck() }
                .keyboardShortcut("b", modifiers: .command)
        }
    }
}
