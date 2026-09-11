import AppKit
import SwiftUI

final class EditorHostView: NSView {
    let gutter = GutterView()
    let scroll = NSScrollView()
    let textView: RideTextView
    var paneID = UUID()
    var onViewport: (() -> Void)?
    var docsStorage: DocController?
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
    let paneID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, state: state)
    }

    func makeNSView(context: Context) -> EditorHostView {
        let host = EditorHostView()
        host.paneID = paneID
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
        EditorPanes.shared.attach(host, pane: paneID)
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
            EditorPanes.shared.attach(host, pane: paneID)
        }
        context.coordinator.flush(host)
    }

    static func dismantleNSView(_ host: EditorHostView, coordinator: Coordinator) {
        coordinator.document.capture(host.textView)
        host.closeDocs()
        EditorPanes.shared.detach(host)
    }
}

struct EditorSplit: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let panes = state.paneLayout.panes
        if panes.count >= 2 {
            splitView(left: panes[0], right: panes[1])
        } else if let pane = panes.first {
            PaneColumn(pane: pane, focused: pane.id == state.paneLayout.focusedID)
        }
    }

    private func splitView(left: Pane, right: Pane) -> some View {
        GeometryReader { geo in
            let total = geo.size.width
            HSplitView {
                PaneColumn(pane: left, focused: left.id == state.paneLayout.focusedID)
                    .frame(minWidth: total * SplitLayout.minRatio)
                    .reportSize(.width) { width in
                        if total > 0 {
                            state.setSplitRatio(width / total)
                        }
                    }
                PaneColumn(pane: right, focused: right.id == state.paneLayout.focusedID)
                    .frame(minWidth: total * SplitLayout.minRatio)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplitPositioner(position: state.splitLayout.ratio * total))
        }
    }
}

struct PaneColumn: View {
    let pane: Pane
    let focused: Bool
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabStrip(pane: pane)
            if focused, state.showFind {
                FindBar()
            }
            if let buffer = state.buffer(pane.activeID) {
                EditorPane(document: buffer, state: state, paneID: pane.id)
                    .id(buffer.id)
            } else {
                WelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
