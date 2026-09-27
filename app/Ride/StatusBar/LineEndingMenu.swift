import AppKit

final class LineEndingMenu: NSObject {
    static let shared = LineEndingMenu()
    private weak var buffer: BufferDocument?

    static func menu(buffer: BufferDocument, policy: String) -> NSMenu {
        shared.buffer = buffer
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (title, crlf) in [("LF", false), ("CRLF", true)] {
            let item = menu.addItem(withTitle: title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = shared
            item.tag = crlf ? 1 : 0
            item.state = buffer.usesCRLF == crlf ? .on : .off
            item.isEnabled = !(crlf && policy == LineEndings.lf)
        }
        return menu
    }

    static func present(buffer: BufferDocument, state: AppState) {
        let menu = menu(buffer: buffer, policy: state.prefs.lineEndings)
        if let event = NSApp.currentEvent, let view = event.window?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    @objc func choose(_ item: NSMenuItem) {
        buffer?.useLineEnding(crlf: item.tag == 1)
    }
}
