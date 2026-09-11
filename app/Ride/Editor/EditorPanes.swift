import AppKit

final class EditorPanes {
    static let shared = EditorPanes()
    var onFocus: ((UUID) -> Void)?
    private var hosts: [UUID: WeakHost] = [:]
    private var focusedID: UUID?

    var focused: EditorHostView? {
        if let focusedID, let host = hosts[focusedID]?.host {
            return host
        }
        return hosts.values.compactMap(\.host).first
    }

    var focusedView: RideTextView? {
        focused?.textView
    }

    func host(_ paneID: UUID) -> EditorHostView? {
        hosts[paneID]?.host
    }

    func host(for view: RideTextView) -> EditorHostView? {
        hosts.values.compactMap(\.host).first { $0.textView === view }
    }

    func attach(_ host: EditorHostView, pane paneID: UUID) {
        hosts[paneID] = WeakHost(host: host)
        if focusedID == nil || hosts[focusedID ?? paneID]?.host == nil {
            focusedID = paneID
        }
    }

    func detach(_ host: EditorHostView) {
        let paneID = host.paneID
        guard hosts[paneID]?.host === host else {
            return
        }
        hosts[paneID] = nil
        if focusedID == paneID {
            focusedID = hosts.keys.first
        }
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
