import Foundation

struct Notice {
    let text: String
    let seconds: Double
    let action: (title: String, run: () -> Void)?
    let onDismiss: (() -> Void)?

    var isActionable: Bool {
        action != nil || onDismiss != nil
    }
}

struct NoticeQueue {
    private(set) var current: Notice?
    private var pending: [Notice] = []

    var pendingCount: Int {
        pending.count
    }

    mutating func push(_ notice: Notice) -> Notice? {
        guard let shown = current else {
            current = notice
            return nil
        }
        guard shown.isActionable else {
            current = notice
            return shown
        }
        if notice.isActionable {
            pending.append(notice)
        } else {
            pending.insert(shown, at: 0)
            current = notice
        }
        return nil
    }

    mutating func advance() -> Notice? {
        current = pending.isEmpty ? nil : pending.removeFirst()
        return current
    }
}
