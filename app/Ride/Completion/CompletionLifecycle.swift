import AppKit

final class CompletionLifecycle {
    private var tokens: [NSObjectProtocol] = []

    init(panel: NSPanel, hide: @escaping () -> Void) {
        let center = NotificationCenter.default
        tokens.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            if !DemoLaunch.isDemo {
                hide()
            }
        })
        tokens.append(center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak panel] note in
            guard let window = note.object as? NSWindow, window !== panel, !DemoLaunch.isDemo else {
                return
            }
            hide()
        })
    }

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}
