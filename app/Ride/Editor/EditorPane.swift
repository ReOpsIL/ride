import AppKit
import SwiftUI

struct EditorPane: NSViewRepresentable {
    @ObservedObject var document: BufferDocument
    @ObservedObject var state: AppState
    let paneID: UUID
    let focused: Bool

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
        host.bind(document)
        host.textView.applyPrefs(state.prefs)
        context.coordinator.boundID = document.id
        host.onViewport = { [weak coordinator = context.coordinator] in
            coordinator?.viewportChanged()
        }
        SessionService.shared.attach(document: document, view: host.textView)
        EditorPanes.shared.attach(host, pane: paneID)
        if focused {
            EditorPanes.shared.adopt(pane: paneID)
        }
        context.coordinator.installHooks(host.textView)
        host.syncGutter()
        return host
    }

    func updateNSView(_ host: EditorHostView, context: Context) {
        context.coordinator.state = state
        host.textView.applyPrefs(state.prefs)
        if focused {
            EditorPanes.shared.adopt(pane: paneID)
        }
        if context.coordinator.boundID != document.id {
            host.capture()
            host.bind(document)
            context.coordinator.document = document
            context.coordinator.boundID = document.id
            context.coordinator.publishCursor(host.textView)
            host.syncGutter()
            SessionService.shared.attach(document: document, view: host.textView)
            EditorPanes.shared.attach(host, pane: paneID)
        }
        state.flushPending(host)
    }

    static func dismantleNSView(_ host: EditorHostView, coordinator: Coordinator) {
        host.capture()
        host.closeDocs()
        host.textView.hooks = EditorHooks()
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
            if focused, state.showFind {
                FindBar()
            }
            if let buffer = state.buffer(pane.activeID) {
                EditorPane(document: buffer, state: state, paneID: pane.id, focused: focused)
                    .id(buffer.id)
            } else {
                WelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
