import AppKit

enum SelfTestMenuCoverage {
    static let separator = " › "

    static func step(state: AppState, suite: Set<String>, known: Set<String>) -> SelfTestStep {
        SelfTestStep(name: "menu coverage", wait: 0.3, run: {}, check: {
            let paths = NSApp.mainMenu.map { leafPaths($0) } ?? []
            let audit = SelfTestMenuAudit(
                paths: paths,
                claims: SelfTestCoverage.claims,
                exempt: SelfTestCoverage.exempt,
                known: known,
                suite: suite,
                passed: DemoSelfTest.shared.passedNames
            )
            DemoSelfTest.shared.attach(name: "menu-coverage.txt", text: audit.listing)
            return audit.problems.isEmpty ? nil : "\(audit.problems.count) problems: " + audit.problems.prefix(12).joined(separator: "; ")
        })
    }

    static func leafPaths(_ menu: NSMenu, prefix: [String] = []) -> [String] {
        menu.items.flatMap { item -> [String] in
            guard !item.isSeparatorItem, !item.isHidden, !item.title.isEmpty else {
                return []
            }
            let path = prefix + [item.title]
            if let submenu = item.submenu {
                return leafPaths(submenu, prefix: path)
            }
            return [path.joined(separator: separator)]
        }
    }
}
