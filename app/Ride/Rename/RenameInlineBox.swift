import AppKit

final class RenameInlineBox: NSObject, NSTextFieldDelegate {
    private let field = NSTextField()
    private weak var host: RideTextView?
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    override init() {
        super.init()
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.font = Tokens.nsMono(13)
        field.usesSingleLineMode = true
        field.delegate = self
    }

    func show(over view: RideTextView, screenRect: NSRect, text: String) {
        host = view
        field.stringValue = text
        field.textColor = ThemeStore.shared.chrome.textPrimary
        let local = viewRect(view, screenRect: screenRect)
        let width = max(120, local.width + 48)
        field.frame = NSRect(x: local.minX - 5, y: local.minY - 4, width: width, height: local.height + 8)
        view.addSubview(field)
        view.window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: (text as NSString).length)
    }

    func hide() {
        if field.superview != nil {
            host?.window?.makeFirstResponder(host)
            field.removeFromSuperview()
        }
    }

    private func viewRect(_ view: RideTextView, screenRect: NSRect) -> NSRect {
        guard let window = view.window, screenRect.width + screenRect.height > 0 else {
            return NSRect(x: 8, y: 8, width: 80, height: 18)
        }
        let inWindow = window.convertFromScreen(screenRect)
        return view.convert(inWindow, from: nil)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            onCancel?()
            return true
        }
        if selector == #selector(NSResponder.insertNewline(_:)) {
            onCommit?(field.stringValue)
            return true
        }
        return false
    }
}
