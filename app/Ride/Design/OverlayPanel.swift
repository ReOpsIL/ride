import AppKit

enum OverlayPanel {
    static let appearDuration = 0.12

    static func make(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = !DemoLaunch.isDemo
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isRestorable = false
        return panel
    }

    static func present(_ panel: NSPanel, frame: NSRect) {
        let wasVisible = panel.isVisible
        panel.setFrame(frame, display: false)
        panel.contentView?.needsLayout = true
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        panel.orderFront(nil)
        guard !wasVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let layer = panel.contentView?.layer
        else {
            return
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = appearDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(fade, forKey: "appear")
    }
}
