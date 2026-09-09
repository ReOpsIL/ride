import AppKit

final class HoverPanel {
    let panel: NSPanel
    private let label = NSTextField(wrappingLabelWithString: "")
    static let maxWidth: CGFloat = 520

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.backgroundColor = NSColor.controlBackgroundColor
        panel.isOpaque = true
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 6
        label.lineBreakMode = .byWordWrapping
        label.frame = NSRect(x: 8, y: 6, width: Self.maxWidth - 16, height: 20)
        let content = NSView(frame: .zero)
        content.addSubview(label)
        panel.contentView = content
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(text: String, anchor: NSRect, screen: NSRect) {
        label.stringValue = text
        label.preferredMaxLayoutWidth = Self.maxWidth - 16
        let size = label.sizeThatFits(NSSize(width: Self.maxWidth - 16, height: 200))
        label.frame = NSRect(x: 8, y: 6, width: size.width, height: size.height)
        let width = size.width + 16
        let height = size.height + 12
        var frame = NSRect(x: anchor.minX, y: anchor.maxY + 4, width: width, height: height)
        if frame.maxY > screen.maxY {
            frame.origin.y = anchor.minY - height - 4
        }
        if frame.maxX > screen.maxX {
            frame.origin.x = max(screen.minX, screen.maxX - width)
        }
        panel.setFrame(frame, display: true)
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}
