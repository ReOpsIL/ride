import AppKit
import SwiftUI

struct RunOutputText: NSViewRepresentable {
    let buffer: RunOutputBuffer
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
        context.coordinator.render(buffer: buffer, theme: theme, fontSize: fontSize)
    }
}

final class RunOutputCoordinator: NSObject, NSTextViewDelegate {
    weak var view: NSTextView?
    var onLink: (ConsoleLink) -> Void
    private var rendered = 0
    private var storedFirst = 0
    private var lengths: [Int] = []
    private var signature = ""

    init(onLink: @escaping (ConsoleLink) -> Void) {
        self.onLink = onLink
    }

    func render(buffer: RunOutputBuffer, theme: Theme, fontSize: CGFloat) {
        guard let storage = view?.textStorage else {
            return
        }
        let stamp = "\(theme.name)-\(fontSize)"
        let plan = RunOutputAppend.plan(
            first: buffer.first,
            end: buffer.end,
            rendered: rendered,
            storedFirst: storedFirst,
            restyle: stamp != signature
        )
        signature = stamp
        apply(plan, storage: storage, first: buffer.first)
        rendered = plan.rendered
        let from = plan.reset ? 0 : plan.appendFrom
        guard from < buffer.lines.count else {
            return
        }
        let text = NSMutableAttributedString()
        for line in buffer.lines[from...] {
            let piece = RunOutputRender.line(line, theme: theme, fontSize: fontSize)
            lengths.append(piece.length + 1)
            text.append(piece)
            text.append(NSAttributedString(string: "\n"))
        }
        storage.append(text)
        view?.scrollRangeToVisible(NSRange(location: storage.length, length: 0))
    }

    private func apply(_ plan: RunOutputAppend.Plan, storage: NSTextStorage, first: Int) {
        if plan.reset {
            storage.setAttributedString(NSAttributedString())
            lengths = []
            storedFirst = first
            return
        }
        guard plan.dropLines > 0, plan.dropLines <= lengths.count else {
            return
        }
        let dropped = lengths[..<plan.dropLines].reduce(0, +)
        storage.deleteCharacters(in: NSRange(location: 0, length: dropped))
        lengths.removeFirst(plan.dropLines)
        storedFirst += plan.dropLines
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let value = link as? String, let parsed = RunOutputRender.decode(value) else {
            return false
        }
        onLink(parsed)
        return true
    }
}
