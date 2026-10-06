import AppKit
import SwiftUI

struct GitDiffScrollView: NSViewRepresentable {
    struct Shown: Equatable {
        let diff: GitFileDiff
        let fontSize: Int
        let theme: String
    }

    let diff: GitFileDiff
    let fontSize: Int

    final class Coordinator {
        var shown: Shown?
        weak var textView: GitDiffTextView?
        weak var gutter: GitDiffGutter?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> GitDiffScroller {
        let textView = Self.makeTextView()
        let scroll = GitDiffScroller()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = textView
        let gutter = GitDiffGutter(scrollView: scroll, orientation: .verticalRuler)
        gutter.clientView = textView
        scroll.verticalRulerView = gutter
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.textView = textView
        context.coordinator.gutter = gutter
        return scroll
    }

    func updateNSView(_ scroll: GitDiffScroller, context: Context) {
        let theme = ThemeStore.shared.theme
        let shown = Shown(diff: diff, fontSize: fontSize, theme: theme.name)
        let coordinator = context.coordinator
        guard coordinator.shown != shown, let textView = coordinator.textView else {
            return
        }
        let fileChanged = coordinator.shown?.diff != diff
        coordinator.shown = shown
        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        let document = GitDiffDocumentBuilder.build(diff, theme: theme, font: font)
        textView.backgroundColor = theme.editor.background
        scroll.backgroundColor = theme.editor.background
        textView.selectedTextAttributes = [.backgroundColor: theme.editor.selection]
        textView.textStorage?.setAttributedString(document.text)
        coordinator.gutter?.font = NSFont.monospacedDigitSystemFont(ofSize: CGFloat(max(fontSize - 2, 9)), weight: .regular)
        coordinator.gutter?.document = document
        if fileChanged {
            scroll.showFromStart()
        } else {
            scroll.fitDocument()
        }
    }

    private static func makeTextView() -> GitDiffTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let unbounded = CGFloat.greatestFiniteMagnitude
        let container = NSTextContainer(size: NSSize(width: unbounded, height: unbounded))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 6
        layout.addTextContainer(container)
        let textView = GitDiffTextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = true
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: unbounded, height: unbounded)
        textView.autoresizingMask = []
        textView.textContainerInset = NSSize(width: 0, height: 4)
        return textView
    }
}
