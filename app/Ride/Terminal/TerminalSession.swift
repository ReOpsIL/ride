import AppKit
import SwiftTerm

final class TerminalSession: NSObject, LocalProcessTerminalViewDelegate {
    let id: UUID
    let terminal: LocalProcessTerminalView
    var onTitle: ((UUID, String) -> Void)?
    var onExit: ((UUID) -> Void)?
    private var alive = true

    init(id: UUID, directory: String?, font: NSFont, colors: TerminalColors) {
        self.id = id
        terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 240))
        super.init()
        terminal.processDelegate = self
        apply(font: font, colors: colors)
        terminal.startProcess(
            executable: TerminalShell.executable(),
            args: TerminalShell.arguments(),
            environment: TerminalShell.environment(),
            execName: nil,
            currentDirectory: directory
        )
    }

    func apply(font: NSFont, colors: TerminalColors) {
        terminal.font = font
        terminal.nativeBackgroundColor = colors.background
        terminal.nativeForegroundColor = colors.foreground
        terminal.caretColor = colors.caret
        terminal.selectedTextBackgroundColor = colors.selection
    }

    func focus() {
        terminal.window?.makeFirstResponder(terminal)
    }

    func terminate() {
        guard alive else {
            return
        }
        alive = false
        terminal.processDelegate = nil
        terminal.terminate()
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        onTitle?(id, title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        alive = false
        onExit?(id)
    }
}
