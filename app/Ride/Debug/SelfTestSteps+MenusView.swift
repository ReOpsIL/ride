import AppKit

extension SelfTestSteps {
    static func menusView(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let panels: [(String, String, () -> Bool)] = [
            ("sidebar", "View › Project Sidebar", { state.showSidebar }),
            ("outline", "View › Outline", { state.prefs.outlinePanel }),
            ("problems", "View › Problems", { state.showProblems }),
            ("run output", "View › Run Output", { state.showRunOutput }),
            ("tests", "View › Tests", { state.showTests }),
            ("usages", "View › Usages", { state.showUsages }),
            ("ai", "View › AI", { AIAssistant.shared.showPanel }),
        ]
        let editorOptions: [(String, String, () -> Bool, () -> Bool)] = [
            ("line numbers", "View › Line Numbers", { state.prefs.lineNumbers }, { true }),
            ("soft wrap", "View › Soft Wrap", { state.prefs.softWrap }, { e.view?.textContainer?.widthTracksTextView == state.prefs.softWrap }),
            ("indent guides", "View › Indent Guides", { state.prefs.indentGuides }, { e.view?.showIndentGuides == state.prefs.indentGuides }),
            ("code vision", "View › Code Vision", { state.prefs.codeVision }, { e.view?.showCodeVision == state.prefs.codeVision }),
        ]
        return panels.flatMap { menuToggle(c, name: $0.0, path: $0.1, read: $0.2) }
            + terminalToggle(c)
            + editorOptions.flatMap { menuToggle(c, name: $0.0, path: $0.1, read: $0.2, applied: $0.3) }
            + whitespaceToggle(c)
            + zoomSteps(c)
    }

    static func menuToggle(
        _ c: SelfTestMenuContext,
        name: String,
        path: String,
        read: @escaping () -> Bool,
        applied: @escaping () -> Bool = { true },
        prepare: @escaping () -> Void = {},
        after: @escaping () -> Void = {}
    ) -> [SelfTestStep] {
        let verify = { (want: Bool) -> (ok: Bool, detail: String) in
            let checked = menuChecked(path)
            return (read() == want && checked == want && applied(), "value \(read()) want \(want) checked \(checked) applied \(applied())")
        }
        return [
            c.step("menu \(name) toggle", path, prepare: {
                prepare()
                c.flag = read()
            }) { verify(!c.flag) },
            c.step("menu \(name) restore", path) {
                let result = verify(c.flag)
                after()
                return result
            },
        ]
    }

    static func menuChecked(_ path: String) -> Bool {
        _ = SelfTestMenu.isEnabled(path)
        return SelfTestMenu.isChecked(path)
    }

    private static func terminalToggle(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        return menuToggle(c, name: "terminal", path: "View › Terminal", read: { state.showTerminal }, applied: {
            !state.showTerminal || !state.terminals.tabs.isEmpty
        }, prepare: {
            c.number = state.terminals.tabs.count
        }, after: {
            if c.number == 0 {
                state.terminals.closeAll()
            }
            c.e.activate()
        })
    }

    private static func whitespaceToggle(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        menuToggle(c, name: "show whitespace", path: "View › Show Whitespace", read: { c.state.prefs.visibleWhitespace })
    }

    private static func zoomSteps(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let applied = { Int(e.view?.baseFont.pointSize ?? 0) == state.prefs.fontSize }
        return [
            c.step("menu zoom in", "View › Zoom In", prepare: { c.number = state.prefs.fontSize }) {
                (state.prefs.fontSize == c.number + 1 && applied(), "font \(state.prefs.fontSize) from \(c.number)")
            },
            c.step("menu zoom out", "View › Zoom Out") {
                (state.prefs.fontSize == c.number && applied(), "font \(state.prefs.fontSize) want \(c.number)")
            },
            c.step("menu actual size", "View › Actual Size", prepare: { state.zoom(2) }) {
                (state.prefs.fontSize == Preferences.defaults.fontSize && applied(), "font \(state.prefs.fontSize)")
            },
        ]
    }
}
