import AppKit

final class SelfTestPopup {
    static let shared = SelfTestPopup()
    private(set) var titles: [String] = []
    private(set) var picked: String?
    private(set) var shown = 0
    private var wanted: String?
    private var token: NSObjectProtocol?

    func arm(pick title: String?) {
        disarm()
        titles = []
        picked = nil
        shown = 0
        wanted = title
        token = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let menu = note.object as? NSMenu, menu.supermenu == nil, menu !== NSApp.mainMenu else {
                return
            }
            self?.captured(menu)
        }
    }

    func disarm() {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
        token = nil
    }

    var done: Bool {
        shown > 0 && (wanted == nil || picked != nil)
    }

    private func captured(_ menu: NSMenu) {
        shown += 1
        titles = menu.items.map(\.title)
        let index = wanted.flatMap { want in menu.items.firstIndex { $0.title == want || $0.title.hasPrefix(want) } }
        Self.soon(0.02) {
            menu.cancelTrackingWithoutAnimation()
        }
        Self.soon(0.1) { [weak self] in
            self?.disarm()
            guard let index, menu.items.indices.contains(index) else {
                return
            }
            self?.picked = menu.items[index].title
            menu.performActionForItem(at: index)
        }
    }

    private static func soon(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in work() }
        RunLoop.main.add(timer, forMode: .common)
    }
}
