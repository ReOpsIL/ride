import SwiftUI

struct EditCommands: Commands {
    let state: AppState
    @ObservedObject var menu: MenuModel

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Duplicate Line") { EditorCommands.duplicate() }
                .keyboardShortcut("d", modifiers: .command)
            Button("Delete Line") { EditorCommands.deleteLines() }
                .keyboardShortcut(.delete, modifiers: .command)
            Button("Join Lines") { EditorCommands.joinLines() }
                .keyboardShortcut("j", modifiers: [.control, .shift])
            Button("Move Line Up") { EditorCommands.moveLines(up: true) }
                .keyboardShortcut(.upArrow, modifiers: [.option, .shift])
            Button("Move Line Down") { EditorCommands.moveLines(up: false) }
                .keyboardShortcut(.downArrow, modifiers: [.option, .shift])
            Button("Move Statement Up") { EditorCommands.moveStatement(up: true) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            Button("Move Statement Down") { EditorCommands.moveStatement(up: false) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            Button("Start New Line") { EditorCommands.newLine(before: false) }
                .keyboardShortcut(.return, modifiers: .shift)
            Button("Start New Line Before") { EditorCommands.newLine(before: true) }
                .keyboardShortcut(.return, modifiers: [.command, .option])
            Button("Toggle Case") { EditorCommands.toggleCase() }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            Button("Sort Lines") { EditorCommands.sortLines() }
            Divider()
            Button("Select Line") { EditorCommands.selectLine() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Select Word") { EditorCommands.selectWord() }
                .keyboardShortcut("w", modifiers: .control)
            Button("Extend Selection") { EditorCommands.extendSelection() }
                .keyboardShortcut(.upArrow, modifiers: .option)
            Button("Shrink Selection") { EditorCommands.shrinkSelection() }
                .keyboardShortcut(.downArrow, modifiers: .option)
            Divider()
            Button("Copy Reference") { state.copyReference() }
                .keyboardShortcut("c", modifiers: [.command, .shift, .option])
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find…") { state.toggleFind() }
                .keyboardShortcut("f", modifiers: .command)
            Button("Find and Replace…") { state.toggleFind(replace: true) }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Button("Find Next") { state.findNext() }
                .keyboardShortcut("g", modifiers: .command)
            Button("Find Previous") { state.findPrevious() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("Use Selection for Find") { state.useSelectionForFind() }
                .keyboardShortcut("e", modifiers: [.command, .option])
            Button("Find in Project…") { state.toggleProjectFind() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            Button("Replace in Project…") { state.toggleProjectFind() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
        }
    }
}
