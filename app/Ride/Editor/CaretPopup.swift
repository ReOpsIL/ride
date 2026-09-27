import AppKit

protocol PinnablePanel: AnyObject {
    var isVisible: Bool { get }
    func setPinned(_ pinned: Bool)
    func hide()
}

final class CaretPopup {
    private unowned let panel: PinnablePanel
    private(set) var pinned = false
    private(set) var generation: UInt64 = 0
    private(set) weak var view: RideTextView?
    private var openedAt: NSRange?

    init(panel: PinnablePanel) {
        self.panel = panel
    }

    func anchor(at utf16: Int, in view: RideTextView) {
        openedAt = IdentifierRange.at(view.string as NSString, index: utf16)
    }

    func begin() -> UInt64 {
        generation += 1
        return generation
    }

    func accepts(_ token: UInt64) -> Bool {
        token == generation
    }

    func present(in view: RideTextView) {
        self.view = view
    }

    func togglePin() {
        pinned.toggle()
        panel.setPinned(pinned)
    }

    func caretMoved() {
        guard panel.isVisible, !pinned, let view else {
            return
        }
        let caret = view.selectedRange()
        if let openedAt, caret.length == 0, NSLocationInRange(caret.location, openedAt) {
            return
        }
        if let openedAt, IdentifierRange.at(view.string as NSString, index: caret.location) == openedAt {
            return
        }
        hide()
    }

    func hideIfUnpinned() {
        if !pinned {
            hide()
        }
    }

    func hide() {
        generation += 1
        pinned = false
        view = nil
        openedAt = nil
        panel.hide()
    }

    static func samePath(_ path: String, _ other: String?) -> Bool {
        guard let other else {
            return false
        }
        return URL(fileURLWithPath: path).standardizedFileURL == URL(fileURLWithPath: other).standardizedFileURL
    }
}

enum PopupPanelKit {
    static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: DocPanel.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = !DemoLaunch.isDemo
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = DemoLaunch.isDemo ? .normal : .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.isRestorable = false
        panel.minSize = NSSize(width: 280, height: 160)
        return panel
    }

    static func configurePin(_ pin: NSButton) {
        pin.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin")
        pin.alternateImage = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pin.setButtonType(.toggle)
        pin.isBordered = false
        pin.imagePosition = .imageOnly
        pin.toolTip = "Pin"
    }

    static func tint(_ pin: NSButton) {
        let chrome = ThemeStore.shared.chrome
        pin.contentTintColor = pin.state == .on ? chrome.accent : chrome.textSecondary
    }

    static func setPinned(_ pin: NSButton, _ pinned: Bool) {
        pin.state = pinned ? .on : .off
        tint(pin)
    }
}
