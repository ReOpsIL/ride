import AppKit

enum Confirm {
    static func ask(_ title: String, message: String = "", ok: String, cancel: String = "Cancel") -> Bool {
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
}
