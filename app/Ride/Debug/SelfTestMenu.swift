import AppKit

enum SelfTestMenu {
    static func item(_ path: String) -> NSMenuItem? {
        var menu = NSApp.mainMenu
        var found: NSMenuItem?
        for title in path.components(separatedBy: SelfTestMenuCoverage.separator) {
            refresh(menu)
            found = menu?.items.first { $0.title == title }
            menu = found?.submenu
        }
        return found
    }

    private static func refresh(_ menu: NSMenu?) {
        guard let menu else {
            return
        }
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
    }

    static func isEnabled(_ path: String) -> Bool {
        guard let item = item(path) else {
            return false
        }
        item.menu?.update()
        return item.isEnabled
    }

    static func isChecked(_ path: String) -> Bool {
        item(path)?.state == .on
    }

    @discardableResult
    static func perform(_ path: String) -> Bool {
        guard let item = item(path), let menu = item.menu else {
            return false
        }
        menu.update()
        guard item.isEnabled else {
            return false
        }
        menu.performActionForItem(at: menu.index(of: item))
        return true
    }
}
