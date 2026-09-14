import AppKit

extension EditorCommands {
    static func generate() {
        guard let target = target(), let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let text = target.text
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: target.selection.location))
        let options = engine.generateOptions(sessionId: id, cursorByte: byte)
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
        var actual = NSRange()
        let rect = target.view.firstRect(forCharacterRange: target.selection, actualRange: &actual)
        let origin = target.view.window.map { target.view.convert($0.convertFromScreen(rect).origin, from: nil) } ?? .zero
        menu.popUp(positioning: nil, at: NSPoint(x: origin.x, y: origin.y), in: target.view)
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
