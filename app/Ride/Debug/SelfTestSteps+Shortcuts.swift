import AppKit

extension SelfTestSteps {
    static func shortcutSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [shortcutsMatchMenus(), shortcutHintsResolve()] + keyRoutingSteps(state: state, e: e)
    }

    static func menuShortcuts(_ menu: NSMenu? = NSApp.mainMenu, prefix: [String] = []) -> [MenuShortcut] {
        (menu?.items ?? []).flatMap { item -> [MenuShortcut] in
            guard !item.isSeparatorItem, !item.isHidden else {
                return []
            }
            let title = item.title.isEmpty ? (item.submenu?.title ?? "") : item.title
            let path = prefix + [title]
            if let submenu = item.submenu {
                return menuShortcuts(submenu, prefix: path)
            }
            guard let combo = KeyCombo(item: item) else {
                return []
            }
            return [MenuShortcut(path: path.joined(separator: ShortcutBinding.separator), combo: combo)]
        }
    }

    private static func shortcutsMatchMenus() -> SelfTestStep {
        SelfTestStep(name: "shortcuts match menus", run: {}, check: {
            let audit = ShortcutAudit(menu: menuShortcuts(), bindings: Shortcuts.bindings, exempt: ShortcutAudit.systemItems)
            DemoSelfTest.shared.attach(name: "shortcuts.txt", text: audit.listing)
            let problems = audit.problems
            if audit.menu.count < 50 {
                return "only \(audit.menu.count) menu key equivalents found"
            }
            return problems.isEmpty ? nil : "\(problems.count) problems: " + problems.prefix(12).joined(separator: "; ")
        })
    }

    private static func shortcutHintsResolve() -> SelfTestStep {
        SelfTestStep(name: "shortcut hints resolve", run: {}, check: {
            let paths = WelcomeView.hints.map(\.0) + ["View › Problems", "Edit › Find Previous", "Edit › Find Next", "Edit › Find and Replace…", "Build › Check"]
            let missing = paths.filter { Shortcuts.keys(for: $0) == nil }
            let menuPaths = Set(menuShortcuts().map(\.path))
            let unbound = paths.filter { !menuPaths.contains($0) }
            return missing.isEmpty && unbound.isEmpty ? nil : "missing \(missing) unbound \(unbound)"
        })
    }
}
