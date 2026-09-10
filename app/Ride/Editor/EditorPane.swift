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
        scroll.backgroundColor = ThemeStore.shared.editor.background
        scroll.documentView = textView
        scroll.contentView.postsBoundsChangedNotifications = true
        gutter.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutter)
        addSubview(scroll)
        gutterWidth = gutter.widthAnchor.constraint(equalToConstant: GutterView.width(digits: 3))
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

    func applyTheme(_ theme: Theme) {
        scroll.backgroundColor = theme.editor.background
        gutter.needsDisplay = true
    }

    @objc func syncGutter() {
        let lines = max(1, textView.lineIndex().lineCount)
        gutterWidth.constant = GutterView.width(digits: String(lines).count)
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
        context.coordinator.installHooks(host.textView)
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
}
