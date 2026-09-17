import AppKit

final class EditorPanes {
    static let shared = EditorPanes()
    var onFocus: ((UUID) -> Void)?
    private var hosts: [UUID: WeakHost] = [:]
    private var focusedID: UUID?
    private var claimedID: UUID?

    var focused: EditorHostView? {
        focusedID.flatMap { hosts[$0]?.host }
    }

    var focusedView: RideTextView? {
        focused?.textView
    }

    var all: [EditorHostView] {
        hosts.values.compactMap(\.host)
    }

    func host(_ paneID: UUID) -> EditorHostView? {
        hosts[paneID]?.host
    }

    func host(for view: RideTextView) -> EditorHostView? {
        all.first { $0.textView === view }
    }

    func host(bound document: BufferDocument) -> EditorHostView? {
        all.first { $0.document === document }
    }

    func attach(_ host: EditorHostView, pane paneID: UUID) {
        hosts[paneID] = WeakHost(host: host)
        if focused == nil {
            focusedID = paneID
        }
        if claimedID == paneID {
            claimedID = nil
            DispatchQueue.main.async {
                host.window?.makeFirstResponder(host.textView)
            }
        }
    }

    func detach(_ host: EditorHostView) {
        guard hosts[host.paneID]?.host === host else {
            return
        }
        hosts[host.paneID] = nil
    }

    func adopt(pane paneID: UUID) {
        if hosts[paneID]?.host != nil {
            focusedID = paneID
        }
        if claimedID != paneID {
            claimedID = nil
        }
    }

    func claim(pane paneID: UUID) {
        claimedID = paneID
    }

    func focus(pane paneID: UUID) {
        guard hosts[paneID]?.host != nil, focusedID != paneID else {
            return
        }
        focusedID = paneID
        onFocus?(paneID)
    }

    func focus(view: RideTextView) {
        if let entry = hosts.first(where: { $0.value.host?.textView === view }) {
            focus(pane: entry.key)
        }
    }
}

private struct WeakHost {
    weak var host: EditorHostView?
}
