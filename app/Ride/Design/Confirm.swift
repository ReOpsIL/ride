import AppKit

enum Confirm {
    static func ask(_ title: String, message: String = "", ok: String, cancel: String = "Cancel") -> Bool {
        if let scripted = DialogScript.next(Bool.self) {
            return scripted
        }
        guard !DemoLaunch.isDemo else {
            return true
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: ok)
        alert.addButton(withTitle: cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func close(_ name: String) -> CloseChoice {
        if let scripted = DialogScript.next(CloseChoice.self) {
            return scripted
        }
        guard !DemoLaunch.isDemo else {
            return .discard
        }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(name)?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        return [.alertFirstButtonReturn: .save, .alertSecondButtonReturn: .discard][alert.runModal()] ?? .cancel
    }

    static func overwrite(_ name: String) -> OverwriteChoice {
        if let scripted = DialogScript.next(OverwriteChoice.self) {
            return scripted
        }
        guard !DemoLaunch.isDemo else {
            return .overwrite
        }
        let alert = NSAlert()
        alert.messageText = "\(name) changed on disk"
        alert.informativeText = "Overwrite the file with your version, or reload it and lose your changes?"
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        return [.alertFirstButtonReturn: .overwrite, .alertSecondButtonReturn: .reload][alert.runModal()] ?? .cancel
    }
}
