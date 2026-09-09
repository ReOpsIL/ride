import AppKit

final class OverlayCardView: NSVisualEffectView {
    private let tint = CALayer()

    init() {
        super.init(frame: .zero)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = Tokens.Radius.card
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = Tokens.Size.hairline
        layer?.insertSublayer(tint, at: 0)
        applyTheme()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func applyTheme() {
        let chrome = ThemeStore.shared.chrome
        layer?.borderColor = chrome.border.cgColor
        tint.backgroundColor = chrome.bgOverlay.withAlphaComponent(0.78).cgColor
    }

    override func layout() {
        super.layout()
        tint.frame = bounds
    }
}
