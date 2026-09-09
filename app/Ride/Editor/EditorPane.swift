import AppKit
import SwiftUI

final class EditorHostView: NSView {
    let gutter = GutterView()
    let scroll = NSScrollView()
    let textView: RideTextView
    var onViewport: (() -> Void)?
    private var gutterWidth: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        textView = RideTextView.makeTK2()
        super.init(frame: frameRect)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.textBackgroundColor
        scroll.documentView = textView
        scroll.contentView.postsBoundsChangedNotifications = true
        gutter.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutter)
        addSubview(scroll)
        gutterWidth = gutter.widthAnchor.constraint(equalToConstant: 36)
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutter.topAnchor.constraint(equalTo: topAnchor),
            gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterWidth,
            scroll.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        gutter.attach(textView: textView)
        onViewport = nil
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewportMoved),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncGutter),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    @objc func syncGutter() {
        let lines = max(1, textView.string.components(separatedBy: "\n").count)
        let digits = max(3, String(lines).count)
        gutterWidth.constant = CGFloat(digits) * 8 + 16
        gutter.needsDisplay = true
    }

    @objc func viewportMoved() {
        gutter.needsDisplay = true
        onViewport?()
    }
}

struct EditorPane: NSViewRepresentable {
    @ObservedObject var document: BufferDocument
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, state: state)
    }

    func makeNSView(context: Context) -> EditorHostView {
        let host = EditorHostView()
        host.textView.applyDefaults()
        host.textView.delegate = context.coordinator
        context.coordinator.textView = host.textView
        context.coordinator.host = host
        document.bind(host.textView)
        host.textView.applyPrefs(state.prefs)
        context.coordinator.boundID = document.id
        host.onViewport = { [weak coordinator = context.coordinator] in
            coordinator?.viewportChanged()
        }
        SessionService.shared.attach(document: document, view: host.textView)
        EditorJump.shared.attach(host: host)
        host.syncGutter()
        return host
    }

    func updateNSView(_ host: EditorHostView, context: Context) {
        context.coordinator.state = state
        host.textView.applyPrefs(state.prefs)
        if context.coordinator.boundID != document.id {
            context.coordinator.document.capture(host.textView)
            document.bind(host.textView)
            context.coordinator.document = document
            context.coordinator.boundID = document.id
            context.coordinator.publishCursor(host.textView)
            host.syncGutter()
            SessionService.shared.attach(document: document, view: host.textView)
            EditorJump.shared.attach(host: host)
        }
        context.coordinator.flush(host)
    }

    static func dismantleNSView(_ host: EditorHostView, coordinator: Coordinator) {
        coordinator.document.capture(host.textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: BufferDocument
        var state: AppState
        var boundID: UUID?
        weak var textView: RideTextView?
        weak var host: EditorHostView?

        init(document: BufferDocument, state: AppState) {
            self.document = document
            self.state = state
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            document.pending = PendingEdit(
                range: affectedCharRange,
                inserted: replacementString ?? "",
                before: textView.string
            )
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? RideTextView else {
                return
            }
            document.text = view.string
            document.isDirty = true
            view.updateCurrentLineHighlight()
            host?.syncGutter()
            publishCursor(view)
            if let pending = document.pending {
                document.pending = nil
                let edit = EditBuild.make(before: pending.before, utf16Range: pending.range, inserted: pending.inserted)
                SessionService.shared.applyEdit(document: document, view: view, edit: edit, inserted: pending.inserted)
            }
            CompletionSession.shared.schedule(document: document, view: view, state: state)
            state.scheduleAutoSave()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let view = notification.object as? RideTextView {
                view.updateCurrentLineHighlight()
                publishCursor(view)
                CompletionSession.shared.selectionChanged(view: view)
            }
        }

        func publishCursor(_ view: NSTextView) {
            let loc = view.selectedRange().location
            let pair = lineAndColumn(in: view.string, utf16: loc)
            if state.cursorLine != pair.0 {
                state.cursorLine = pair.0
            }
            if state.cursorColumn != pair.1 {
                state.cursorColumn = pair.1
            }
        }

        func viewportChanged() {
            guard let view = textView else {
                return
            }
            SessionService.shared.setVisible(document: document, view: view)
        }

        func flush(_ host: EditorHostView) {
            if let text = state.applyText {
                state.applyText = nil
                document.text = text
                EditorJump.shared.replaceText(text)
                SessionService.shared.resync(document: document, view: host.textView)
            }
        }
    }
}
