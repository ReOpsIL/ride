import AppKit

final class EditorJump {
    static let shared = EditorJump()
    weak var view: RideTextView?
    weak var host: EditorHostView?

    func attach(host: EditorHostView) {
        self.host = host
        view = host.textView
    }

    func jump(byte: UInt32) {
        guard let view else {
            return
        }
        let ns = Utf16.nsRange(in: view.string, startByte: byte, endByte: byte)
        select(NSRange(location: ns.location, length: 0))
    }

    func select(_ range: NSRange) {
        guard let view else {
            return
        }
        let length = view.textStorage?.length ?? 0
        let loc = min(max(range.location, 0), length)
        let len = min(max(range.length, 0), length - loc)
        let clamped = NSRange(location: loc, length: len)
        view.window?.makeFirstResponder(view)
        view.setSelectedRange(clamped)
        if loc == 0 {
            view.enclosingScrollView?.contentView.scroll(to: .zero)
            view.enclosingScrollView?.reflectScrolledClipView(view.enclosingScrollView!.contentView)
        } else {
            view.scrollRangeToVisible(NSRange(location: loc, length: max(len, 1)))
        }
        view.updateCurrentLineHighlight()
        host?.syncGutter()
    }

    func jump(toLine line: Int) {
        guard let view else {
            return
        }
        let starts = view.lineIndex().starts
        let loc = starts[min(max(line, 1), starts.count) - 1]
        select(NSRange(location: loc, length: 0))
    }

    func replaceText(_ text: String) {
        guard let view else {
            return
        }
        view.string = text
        view.lines.invalidate()
        host?.syncGutter()
        view.updateCurrentLineHighlight()
    }
}
