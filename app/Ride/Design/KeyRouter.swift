import AppKit

protocol ClaimsKeysBeforeMenus: NSResponder {
    func claimsKeyBeforeMenus(_ event: NSEvent) -> Bool
}

enum KeyRouter {
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else {
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { route($0) }
    }

    static func route(_ event: NSEvent) -> NSEvent? {
        guard let responder = (event.window ?? NSApp.keyWindow)?.firstResponder, claims(responder, event) else {
            return event
        }
        responder.keyDown(with: event)
        return nil
    }

    static func claims(_ responder: NSResponder, _ event: NSEvent) -> Bool {
        if let claimant = responder as? ClaimsKeysBeforeMenus, responder === EditorPanes.shared.focusedView {
            return claimant.claimsKeyBeforeMenus(event)
        }
        guard let combo = KeyCombo(event: event) else {
            return false
        }
        return Shortcuts.editorScoped.contains(combo)
    }
}
