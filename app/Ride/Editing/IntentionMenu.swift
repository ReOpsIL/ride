import AppKit

extension EditorCommands {
    static func showIntentions() {
        guard let target = target(), let id = target.document.sessionId else {
            return
        }
        let scheduled = IntentionActions.fetch(
            sessionId: id,
            path: target.document.fileURL?.standardizedFileURL.path,
            text: target.text,
            caret: target.selection.location
        ) { items in
            guard !items.isEmpty else {
                target.state.showNotice(IntentionMenu.emptyNotice)
                return
            }
            IntentionMenu.pop(items, target: target)
        }
        if !scheduled {
            target.state.showNotice(IntentionMenu.emptyNotice)
        }
    }

    static func applyIntention(matching prefix: String) {
        guard let target = target(), let id = target.document.sessionId else {
            return
        }
        IntentionActions.fetch(
            sessionId: id,
            path: target.document.fileURL?.standardizedFileURL.path,
            text: target.text,
            caret: target.selection.location
        ) { items in
            guard let intention = items.first(where: { $0.title.hasPrefix(prefix) }) else {
                target.state.showNotice(IntentionMenu.emptyNotice)
                return
            }
            IntentionActions.apply(intention, to: target.view)
        }
    }
}

enum IntentionMenu {
    static let emptyNotice = "No intention actions here"

    static func pop(_ items: [Intention], target: EditorTarget) {
        let menu = NSMenu()
        for item in items {
            let entry = NSMenuItem(
                title: item.title,
                action: #selector(IntentionMenuTarget.pick(_:)),
                keyEquivalent: ""
            )
            entry.representedObject = IntentionBox(intention: item, view: target.view)
            entry.target = IntentionMenuTarget.shared
            menu.addItem(entry)
        }
        var actual = NSRange()
        let rect = target.view.firstRect(forCharacterRange: target.selection, actualRange: &actual)
        let origin = target.view.window.map {
            target.view.convert($0.convertFromScreen(rect).origin, from: nil)
        } ?? .zero
        menu.popUp(positioning: nil, at: NSPoint(x: origin.x, y: origin.y), in: target.view)
    }
}

final class IntentionBox: NSObject {
    let intention: Intention
    let view: RideTextView

    init(intention: Intention, view: RideTextView) {
        self.intention = intention
        self.view = view
    }
}

final class IntentionMenuTarget: NSObject {
    static let shared = IntentionMenuTarget()

    @objc func pick(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? IntentionBox else {
            return
        }
        IntentionActions.apply(box.intention, to: box.view)
    }
}
