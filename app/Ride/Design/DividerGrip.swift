import AppKit

final class DividerGrip: NSView {
    static let thickness: CGFloat = 6
    static let length: CGFloat = 40

    static var fill: NSColor {
        let chrome = ThemeStore.shared.chrome
        return chrome.bgBase.blended(withFraction: 0.7, of: chrome.textSecondary) ?? chrome.textSecondary
    }
    private weak var split: NSSplitView?
    private var observer: NSObjectProtocol?

    static func install(in split: NSSplitView) {
        if split.subviews.contains(where: { $0 is DividerGrip }) {
            return
        }
        let grip = DividerGrip(frame: .zero)
        grip.split = split
        grip.wantsLayer = true
        grip.layer?.zPosition = 100
        split.addSubview(grip, positioned: .above, relativeTo: nil)
        grip.observer = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: split,
            queue: .main
        ) { [weak grip] _ in
            grip?.reposition()
        }
        grip.reposition()
    }

    override var isFlipped: Bool { true }

    func reposition() {
        guard let split, split.arrangedSubviews.count > 1 else {
            isHidden = true
            return
        }
        isHidden = false
        let a = split.arrangedSubviews[0].frame
        let b = split.arrangedSubviews[1].frame
        let t = Self.thickness
        let l = Self.length
        if split.isVertical {
            let (left, right) = a.minX <= b.minX ? (a, b) : (b, a)
            let center = (left.maxX + right.minX) / 2
            frame = NSRect(x: center - t / 2, y: split.bounds.midY - l / 2, width: t, height: l)
        } else {
            let (lower, upper) = a.minY <= b.minY ? (a, b) : (b, a)
            let center = (lower.maxY + upper.minY) / 2
            frame = NSRect(x: split.bounds.midX - l / 2, y: center - t / 2, width: l, height: t)
        }
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        reposition()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: Self.thickness / 2, yRadius: Self.thickness / 2)
        Self.fill.setFill()
        path.fill()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
