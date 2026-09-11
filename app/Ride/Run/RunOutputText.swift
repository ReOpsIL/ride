import AppKit
import SwiftUI

struct RunOutputText: NSViewRepresentable {
    let lines: [String]
    let theme: Theme
    let fontSize: CGFloat
    let onLink: (ConsoleLink) -> Void

    func makeCoordinator() -> RunOutputCoordinator {
        RunOutputCoordinator(onLink: onLink)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else {
            return scroll
        }
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = true
        view.textContainerInset = NSSize(width: 6, height: 6)
        view.delegate = context.coordinator
        view.linkTextAttributes = [:]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        context.coordinator.view = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        scroll.backgroundColor = theme.editor.background
        context.coordinator.view?.backgroundColor = theme.editor.background
        context.coordinator.onLink = onLink
        context.coordinator.render(lines: lines, theme: theme, fontSize: fontSize)
    }
}

final class RunOutputCoordinator: NSObject, NSTextViewDelegate {
    weak var view: NSTextView?
    var onLink: (ConsoleLink) -> Void
    private var rendered = 0
    private var signature = ""

    init(onLink: @escaping (ConsoleLink) -> Void) {
        self.onLink = onLink
    }

    func render(lines: [String], theme: Theme, fontSize: CGFloat) {
        guard let storage = view?.textStorage else {
            return
        }
        let stamp = "\(theme.name)-\(fontSize)"
        let reset = stamp != signature || lines.count < rendered
        if reset {
            storage.setAttributedString(NSAttributedString())
            rendered = 0
            signature = stamp
        }
        guard lines.count > rendered else {
            return
        }
        let added = lines[rendered...]
        let text = NSMutableAttributedString()
        for line in added {
            text.append(RunOutputRender.line(line, theme: theme, fontSize: fontSize))
            text.append(NSAttributedString(string: "\n"))
        }
        storage.append(text)
        rendered = lines.count
        view?.scrollRangeToVisible(NSRange(location: storage.length, length: 0))
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let value = link as? String, let parsed = RunOutputRender.decode(value) else {
            return false
        }
        onLink(parsed)
        return true
    }
}
