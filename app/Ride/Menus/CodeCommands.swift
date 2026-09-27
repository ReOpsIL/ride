import SwiftUI

struct CodeCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandMenu("Code") {
            editing
            Divider()
            wrapping
            Divider()
            assistance
        }
        CommandMenu("Build") {
            Button("Check") { state.runCheck() }
                .keyboardShortcut("b", modifiers: [.command, .option])
                .disabled(!menu.code.check)
            Button("Check Project") { state.runProjectCheck() }
                .keyboardShortcut("b", modifiers: [.command, .option, .shift])
                .disabled(!menu.code.projectCheck)
            Divider()
            Button("Install Tools…") { state.showToolsSheet = true }
        }
    }

    @ViewBuilder private var editing: some View {
        Button("Comment Line") { EditorCommands.commentLine() }
            .keyboardShortcut("/", modifiers: .command)
            .disabled(!menu.code.editor)
        Button("Comment Block") { EditorCommands.commentBlock() }
            .keyboardShortcut("/", modifiers: [.command, .option])
            .disabled(!menu.code.editor)
        Divider()
        Button("Indent") { EditorCommands.indent() }
            .disabled(!menu.code.editor)
        Button("Unindent") { EditorCommands.unindent() }
            .disabled(!menu.code.editor)
        Button("Auto-Indent Lines") { EditorCommands.autoIndent() }
            .keyboardShortcut("i", modifiers: [.control, .option])
            .disabled(!menu.code.editor)
        Button("Reformat Document") { state.formatActive() }
            .keyboardShortcut("i", modifiers: [.control, .shift])
            .disabled(!menu.code.editor)
        Button("Reformat Selection") { state.formatSelection() }
            .keyboardShortcut("l", modifiers: [.command, .option])
            .disabled(!menu.code.editor)
        Button("Complete Statement") { EditorCommands.completeStatement() }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(!menu.code.statement)
        refactoring
    }

    @ViewBuilder private var refactoring: some View {
        Button("Generate…") { EditorCommands.generate() }
            .keyboardShortcut("g", modifiers: [.control, .command])
            .disabled(!menu.code.generate)
        Button("Extract Variable") { EditorCommands.extractVariable() }
            .keyboardShortcut("v", modifiers: [.command, .option])
            .disabled(!menu.code.extract)
        Button("Introduce Constant") { EditorCommands.introduceConstant() }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(!menu.code.refactor)
        Button("Inline Variable") { EditorCommands.inlineVariable() }
            .keyboardShortcut("n", modifiers: [.control, .option])
            .disabled(!menu.code.refactor)
        Button("Show Intention Actions") { EditorCommands.showIntentions() }
            .keyboardShortcut(.return, modifiers: .option)
            .disabled(!menu.code.editor)
        Button("Ask AI from Comment…") { AIAssistant.shared.askFromEditor(state: state) }
            .keyboardShortcut("?", modifiers: .control)
            .disabled(!menu.code.editor)
    }

    @ViewBuilder private var wrapping: some View {
        Button("Surround With…") { EditorCommands.surroundWith() }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .disabled(!menu.code.editor)
        Button("Fold") { FoldController.shared.fold() }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(!menu.code.editor)
        Button("Unfold") { FoldController.shared.unfold() }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(!menu.code.editor)
        Button("Fold All") { FoldController.shared.foldAll() }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option, .shift])
            .disabled(!menu.code.editor)
        Button("Unfold All") { FoldController.shared.unfoldAll() }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .shift])
            .disabled(!menu.code.editor)
    }

    @ViewBuilder private var assistance: some View {
        Button("Trigger Completion") { EditorCommands.triggerCompletion() }
            .keyboardShortcut(.space, modifiers: .control)
            .disabled(!menu.code.editor)
        Button("Cheat Sheet") { EditorCommands.toggleCheatSheet() }
            .keyboardShortcut(.space, modifiers: [.control, .shift])
            .disabled(!menu.code.cheatSheet)
        Button("Quick Documentation") { DocController.showFocused() }
            .keyboardShortcut("j", modifiers: .control)
            .disabled(!menu.code.editor)
        Button("Quick Documentation") { DocController.showFocused() }
            .keyboardShortcut(FunctionKeys.f1, modifiers: [])
            .disabled(!menu.code.editor)
        Button("Quick Definition") { PeekController.showFocused() }
            .keyboardShortcut(.space, modifiers: .option)
            .disabled(!menu.code.editor)
        Button("External Documentation") { DocController.showExternalFocused() }
            .keyboardShortcut(FunctionKeys.f1, modifiers: .shift)
            .disabled(!menu.code.editor)
        Button("Signature Help") { state.showSignatureHelp() }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
            .disabled(!menu.code.signature)
    }
}
