import AppKit

extension SelfTestSteps {
    static func menusNavigate(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let bumpLines = { [c.lineOf("fn bump(&mut self);"), c.lineOf("fn bump(&mut self) {")] }
        return [
            c.openStep("menu probe reopen", c.probeURL),
            SelfTestStep(name: "menu last edit prep", wait: 0.4, run: {
                c.resetProbe()
                c.caret(on: "let c = 3", offset: 9)
                e.type("0")
                e.caret(line: 1)
            }, check: {
                e.expect(e.text.contains("let c = 30;") && e.caretLine == 1, "caret \(e.caretLine)")
            }),
            c.step("menu last edit", "Navigate › Last Edit Location") {
                (e.caretLine == c.lineOf("let c = 30;"), "caret \(e.caretLine) edit at \(c.lineOf("let c = 30;"))")
            },
            c.step("menu go to definition", "Navigate › Go to Definition", until: { bumpLines().contains(e.caretLine) }, timeout: 10, prepare: {
                c.resetProbe()
                c.caret(on: "probe.bump();", offset: 7)
            }) {
                (bumpLines().contains(e.caretLine), "caret \(e.caretLine) want \(bumpLines())")
            },
            c.step("menu find usages", "Navigate › Find Usages", until: { state.usages.finished && !state.usages.running }, timeout: 20, prepare: {
                c.caret(on: "fn bump(&mut self) {", offset: 4)
            }) {
                (state.showUsages && state.usages.name == "bump" && state.usages.total >= 2, "name \(state.usages.name) total \(state.usages.total)")
            },
            c.step("menu call hierarchy", "Navigate › Call Hierarchy", until: { state.hierarchy.finished && !state.hierarchy.running }, timeout: 20, prepare: {
                state.showUsages = false
                c.caret(on: "fn bump(&mut self) {", offset: 4)
            }) {
                (state.showHierarchy && state.hierarchy.mode == .callers && state.hierarchy.rootName == "bump", "root \(state.hierarchy.rootName) mode \(state.hierarchy.mode)")
            },
            c.step("menu type hierarchy", "Navigate › Type Hierarchy", until: { state.hierarchy.finished && !state.hierarchy.running }, timeout: 20, prepare: {
                c.caret(on: "struct MenuProbe", offset: 8)
            }) {
                let ok = state.showHierarchy && state.hierarchy.mode == .types && state.hierarchy.rootName == "MenuProbe"
                state.hideHierarchy()
                return (ok, "root \(state.hierarchy.rootName) mode \(state.hierarchy.mode)")
            },
        ] + problemSteps(c) + methodSteps(c)
    }

    private static func problemSteps(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let target = { c.lineOf("fn menu_probe_unused") }
        return [
            c.step("menu next problem", "Navigate › Next Problem", wait: 0.5, prepare: {
                c.flag = state.showProblems
                injectProblem(c)
                e.caret(line: 1)
            }) {
                (e.caretLine == target() && c.activeName == "menu_probe.rs", "caret \(e.caretLine) want \(target()) in \(c.activeName)")
            },
            c.step("menu previous problem", "Navigate › Previous Problem", wait: 0.5, prepare: {
                e.caret(line: e.lines.count)
            }) {
                let result = (e.caretLine == target(), "caret \(e.caretLine) want \(target())")
                CheckService.shared.replaceBuild([])
                state.showProblems = c.flag
                return result
            },
        ]
    }

    private static func injectProblem(_ c: SelfTestMenuContext) {
        guard let path = c.probeURL?.path else {
            return
        }
        let text = c.e.text
        let utf16 = (text as NSString).range(of: "fn menu_probe_unused").location
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: utf16))
        let line = UInt32(c.lineOf("fn menu_probe_unused"))
        let diagnostic = Diagnostic(
            path: path,
            byteStart: byte,
            byteEnd: byte + 2,
            line: line,
            column: 1,
            level: .warning,
            message: "menu probe warning",
            code: nil,
            fixes: []
        )
        CheckService.shared.replaceBuild([diagnostic])
    }

    private static func methodSteps(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let e = c.e
        let starts = { () -> [Int] in
            let text = e.text
            return (c.state.activeBuffer?.outline ?? []).map { row in
                (text as NSString).lineNumber(at: Utf16.utf16Offset(in: text, utf8: Int(row.startByte)))
            }.sorted()
        }
        return [
            c.step("menu next method", "Navigate › Next Method", prepare: { c.caret(on: "pub fn menu_probe_used", offset: 2) }) {
                let want = starts().first { $0 > c.lineOf("pub fn menu_probe_used") } ?? -1
                return (e.caretLine == want, "caret \(e.caretLine) want \(want) starts \(starts())")
            },
            c.step("menu previous method", "Navigate › Previous Method") {
                (e.caretLine == c.lineOf("pub fn menu_probe_used"), "caret \(e.caretLine) starts \(starts())")
            },
            c.step("menu matching brace", "Navigate › Matching Brace", prepare: { c.caret(on: "pub struct MenuProbe {", offset: 21) }) {
                (e.caretLine == c.lineOf("pub hits: u32,") + 1, "caret \(e.caretLine)")
            },
        ]
    }
}
