import AppKit

extension SelfTestSteps {
    static func menusOverlays(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let names = { state.quickHits.map(\.lastPathComponent) }
        return [
            c.step("menu open quickly", "Navigate › Open Quickly…", until: { !state.quickHits.isEmpty }, timeout: 10, prepare: {
                state.closeOverlays()
                c.openProbe()
            }) {
                (state.overlay == .quickOpen && names().contains("util.rs"), "overlay \(String(describing: state.overlay)) hits \(names())")
            },
            SelfTestStep(name: "menu open quickly keys", run: {
                state.quickQuery = ".rs"
                state.refreshQuickOpen()
                state.quickSelection = state.quickHits.first
                c.location = state.quickHits.count
                state.selectNextQuick()
                state.selectPreviousQuick()
                state.selectPreviousQuick()
            }, check: {
                c.e.expect(c.location > 1 && state.quickSelection == state.quickHits.last, "hits \(names()) selection \(state.quickSelection?.lastPathComponent ?? "nil")")
            }),
            SelfTestStep(name: "menu open quickly open", wait: 0.4, run: {
                state.quickQuery = "util"
                state.refreshQuickOpen()
                state.confirmQuickOpen()
            }, check: {
                c.e.expect(c.activeName == "util.rs" && state.overlay == nil, "active \(c.activeName) overlay \(String(describing: state.overlay))")
            }),
            c.step("menu open quickly replaces overlay", "Navigate › Open Quickly…", prepare: { state.toggleGoToLine() }) {
                (state.overlay == .quickOpen && !state.showGoToLine, "overlay \(String(describing: state.overlay))")
            },
            c.step("menu open quickly close", "Navigate › Open Quickly…") {
                (state.overlay == nil, "overlay \(String(describing: state.overlay))")
            },
            c.step("menu recent files", "Navigate › Recent Files…", prepare: { c.openProbe() }) {
                (
                    state.overlay == .recentFiles && state.recentSelection?.lastPathComponent == "util.rs",
                    "overlay \(String(describing: state.overlay)) selection \(state.recentSelection?.lastPathComponent ?? "nil")"
                )
            },
            SelfTestStep(name: "menu recent files open", wait: 0.4, run: {
                state.recentQuery = "util"
                state.moveRecentSelection(1)
                state.confirmRecentFile()
            }, check: {
                c.e.expect(c.activeName == "util.rs" && state.overlay == nil, "active \(c.activeName)")
            }),
            c.step("menu back", "Navigate › Back", wait: 0.4) {
                (c.activeName == "menu_probe.rs", "active \(c.activeName)")
            },
            c.step("menu forward", "Navigate › Forward", wait: 0.4) {
                (c.activeName == "util.rs", "active \(c.activeName)")
            },
        ] + goToLineSteps(c) + symbolSteps(c)
    }

    private static func goToLineSteps(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        return [
            c.step("menu go to line", "Navigate › Go to Line…", prepare: { c.openProbe() }) {
                (state.overlay == .goToLine && state.goToLineQuery.isEmpty, "overlay \(String(describing: state.overlay))")
            },
            SelfTestStep(name: "menu go to line confirm", run: {
                state.goToLineQuery = "6:9"
                state.confirmGoToLine()
            }, check: {
                let column = (e.view?.selectedRange().location ?? 0) - e.lineRange(6).location
                return e.expect(e.caretLine == 6 && column == 8 && state.overlay == nil, "caret \(e.caretLine) column \(column + 1)")
            }),
            c.step("menu go to line reopen", "Navigate › Go to Line…") {
                (state.showGoToLine, "overlay \(String(describing: state.overlay))")
            },
            c.step("menu go to line toggle", "Navigate › Go to Line…") {
                (state.overlay == nil, "overlay \(String(describing: state.overlay))")
            },
        ]
    }

    private static func symbolSteps(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let rows = { state.symbolRows.map(\.name) }
        let util = c.url("src/util.rs")?.resolvingSymlinksInPath().path
        let isUtil = { (hit: CompletionHit) in hit.sourcePath.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path } == util }
        return [
            c.step("menu symbol in file", "Navigate › Go to Symbol in File…") {
                (state.overlay == .symbolInFile && state.symbolSelection == state.activeBuffer?.outline.first?.startByte && rows().count > 3, "overlay \(String(describing: state.overlay)) rows \(rows())")
            },
            SelfTestStep(name: "menu symbol in file filter", run: {
                state.symbolQuery = "unused"
                state.symbolQueryChanged()
                state.moveSymbolSelection(1)
                state.confirmSymbolInFile()
            }, check: {
                e.expect(e.caretLine == c.lineOf("fn menu_probe_unused") && state.overlay == nil, "caret \(e.caretLine) rows \(rows())")
            }),
            c.step("menu symbol in file reopen", "Navigate › Go to Symbol in File…") {
                (state.showSymbolInFile, "overlay \(String(describing: state.overlay))")
            },
            c.step("menu symbol in file toggle", "Navigate › Go to Symbol in File…") {
                (state.overlay == nil, "overlay \(String(describing: state.overlay))")
            },
            c.step("menu symbol in project", "Navigate › Go to Symbol in Project…", until: {
                let picker = state.symbolPicker
                guard state.showSymbolPicker else {
                    return true
                }
                if picker.query.isEmpty {
                    picker.query = "Counter"
                }
                guard let index = picker.hits.firstIndex(where: isUtil) ?? picker.hits.firstIndex(where: { $0.sourcePath != nil }) else {
                    picker.refresh()
                    return false
                }
                c.flag = true
                c.target = picker.hits[index].sourcePath.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
                picker.selection = index
                picker.move(1)
                picker.move(-1)
                state.confirmSymbolPicker()
                return true
            }, timeout: 15, prepare: { c.flag = false }) {
                (c.flag, "overlay \(String(describing: state.overlay)) hits \(state.symbolPicker.hits.prefix(5).map { $0.sourcePath ?? $0.name })")
            },
            SelfTestStep(name: "menu symbol in project open", run: {}, check: {
                let active = state.activeBuffer?.fileURL?.resolvingSymlinksInPath().path
                return e.expect(active != nil && active == c.target && state.overlay == nil && e.text.contains("Counter"), "active \(active ?? "nil") want \(c.target ?? "nil")")
            }),
        ]
    }
}
