import AppKit

extension EditorCommands {
    static func generate() {
        guard let target = target() else {
            return
        }
        let options = target.session { $0.generateOptions(sessionId: $1, cursorByte: target.caretByte) } ?? []
        guard !options.isEmpty else {
            target.state.showNotice("Nothing to generate here")
            return
        }
        let menu = NSMenu()
        for option in options {
            let item = NSMenuItem(title: option.title, action: #selector(GenerateMenuTarget.pick(_:)), keyEquivalent: "")
            item.representedObject = GenerateBox(kind: option.kind)
            item.target = GenerateMenuTarget.shared
            menu.addItem(item)
        }
        IntentionMenu.pop(menu, at: target)
    }
}

final class GenerateBox: NSObject {
    let kind: GenKind

    init(kind: GenKind) {
        self.kind = kind
    }
}

final class GenerateMenuTarget: NSObject {
    static let shared = GenerateMenuTarget()

    @objc func pick(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? GenerateBox else {
            return
        }
        EditorCommands.applyGenerator(box.kind)
    }
}
