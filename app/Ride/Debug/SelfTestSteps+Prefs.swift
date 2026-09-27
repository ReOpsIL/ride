import AppKit

final class PrefScratch {
    var width: CGFloat = 0
    var height: CGFloat = 0
    var shades = 0
    var flag = false
    var version: UInt64 = 0
    var disk = ""
    var typedAt = 0
    var typedLength = 0
    var saved = Preferences.defaults
    var line = ""
    var stableSince = Date()
    var y: CGFloat = 0
}

extension SelfTestSteps {
    static func prefSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let bind = PreferenceBindings(state: state)
        let p = PrefScratch()
        return [prefBaseline(state: state, e: e, p: p)] + prefGeneralSteps(state: state, e: e, bind: bind, p: p)
            + prefDisplaySteps(state: state, e: e, bind: bind, p: p)
            + prefPopupSteps(state: state, e: e, bind: bind, p: p)
            + prefToolSteps(state: state, e: e, bind: bind, p: p)
            + prefAISteps(state: state, e: e, bind: bind)
            + [prefRestore(state: state, e: e, p: p)]
    }

    private static func prefBaseline(state: AppState, e: SelfTestEditor, p: PrefScratch) -> SelfTestStep {
        SelfTestStep(name: "pref baseline", wait: 0.6, run: {
            p.saved = state.prefs
            state.updatePrefs { prefs in
                let layout = prefs
                prefs = Preferences.defaults
                prefs.sidebarWidth = layout.sidebarWidth
                prefs.outlineWidth = layout.outlineWidth
                prefs.hierarchyWidth = layout.hierarchyWidth
                prefs.previewWidth = layout.previewWidth
                prefs.problemsHeight = layout.problemsHeight
                prefs.runOutputHeight = layout.runOutputHeight
                prefs.terminalHeight = layout.terminalHeight
                prefs.testsHeight = layout.testsHeight
                prefs.debugHeight = layout.debugHeight
                prefs.aiProvider = layout.aiProvider
                prefs.aiModel = layout.aiModel
            }
        }, check: { e.expect(state.prefs.outlinePanel && state.prefs.indentGuides && !state.prefs.visibleWhitespace, "baseline not applied") })
    }

    private static func prefRestore(state: AppState, e: SelfTestEditor, p: PrefScratch) -> SelfTestStep {
        SelfTestStep(name: "pref restore", wait: 0.6, run: { state.updatePrefs { $0 = p.saved } }, check: {
            e.expect(state.prefs == p.saved.clamped, "preferences differ from the saved ones")
        })
    }

    static func prefGeneralSteps(state: AppState, e: SelfTestEditor, bind: PreferenceBindings, p: PrefScratch) -> [SelfTestStep] {
        let hidden = (state.workspaceRoot ?? URL(fileURLWithPath: "/")).appendingPathComponent(".ride_hidden_probe")
        let listed = { state.rootNodes.contains { $0.url.lastPathComponent == hidden.lastPathComponent } }
        return [
            SelfTestStep(name: "pref theme light", wait: 0.5, run: { bind.theme.wrappedValue = "light" }, check: {
                e.expect(!ThemeStore.shared.theme.isDark && NSApp.appearance?.name == .aqua && e.view?.backgroundColor == ThemeStore.shared.theme.editor.background,
                         "dark \(ThemeStore.shared.theme.isDark) appearance \(String(describing: NSApp.appearance?.name))")
            }),
            SelfTestStep(name: "pref theme dark", wait: 0.5, run: { bind.theme.wrappedValue = "dark" }, check: {
                e.expect(ThemeStore.shared.theme.isDark && NSApp.appearance?.name == .darkAqua, "dark \(ThemeStore.shared.theme.isDark)")
            }),
            SelfTestStep(name: "pref font size", wait: 0.4, run: { bind.int(\.fontSize).wrappedValue = 20 }, check: {
                let editor = e.view?.font?.pointSize ?? 0
                let terminal = state.terminals.font.pointSize
                bind.int(\.fontSize).wrappedValue = Preferences.defaults.fontSize
                return e.expect(editor == 20 && terminal == 20 && state.prefs.fontSize == Preferences.defaults.fontSize, "editor \(editor) terminal \(terminal)")
            }),
            SelfTestStep(name: "pref tab width", wait: 0.8, run: {
                bind.int(\.tabWidth).wrappedValue = 2
                e.caret(line: 1)
                p.line = e.line(1)
                DemoLaunch.after(0.4) { e.view?.insertTab(nil) }
            }, check: {
                let after = e.line(1)
                let width = e.view?.tabWidth ?? 0
                e.undo()
                bind.int(\.tabWidth).wrappedValue = 4
                return e.expect(width == 2 && after == "  " + p.line && state.prefs.tabWidth == 4, "width \(width) line '\(p.line)' -> '\(after)'")
            }),
            SelfTestStep(name: "pref show hidden files", wait: 0.4, run: {
                FileManager.default.createFile(atPath: hidden.path, contents: Data())
                state.reloadTree()
                bind.bool(\.showHidden).wrappedValue = true
            }, check: { e.expect(listed(), "hidden file not listed") }),
            SelfTestStep(name: "pref hide hidden files", wait: 0.4, run: { bind.bool(\.showHidden).wrappedValue = false }, check: {
                let shown = listed()
                try? FileManager.default.removeItem(at: hidden)
                state.reloadTree()
                return e.expect(!shown, "hidden file still listed")
            }),
        ]
    }
}
