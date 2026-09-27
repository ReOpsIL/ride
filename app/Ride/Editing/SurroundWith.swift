import AppKit

enum SurroundWith {
    static func templates(for target: EditorTarget) -> [SurroundTemplate] {
        SurroundTemplates.all(for: target.document.language, tokens: target.tokens)
    }

    static func apply(_ template: SurroundTemplate, to target: EditorTarget) -> EditResult {
        SurroundEdit.result(template, text: target.text, selection: target.selection, unit: target.unit)
    }
}

extension EditorCommands {
    static func surroundWith() {
        guard let target = target() else {
            return
        }
        let menu = NSMenu()
        for template in SurroundWith.templates(for: target) {
            let item = NSMenuItem(title: template.title, action: #selector(SurroundMenuTarget.pick(_:)), keyEquivalent: "")
            item.representedObject = SurroundBox(template: template, target: target)
            item.target = SurroundMenuTarget.shared
            menu.addItem(item)
        }
        IntentionMenu.pop(menu, at: target)
    }
}

final class SurroundBox: NSObject {
    let template: SurroundTemplate
    let target: EditorTarget

    init(template: SurroundTemplate, target: EditorTarget) {
        self.template = template
        self.target = target
    }
}

final class SurroundMenuTarget: NSObject {
    static let shared = SurroundMenuTarget()

    @objc func pick(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? SurroundBox else {
            return
        }
        EditorCommand.apply(SurroundWith.apply(box.template, to: box.target), to: box.target.view)
    }
}
