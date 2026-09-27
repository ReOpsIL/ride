import AppKit

extension SelfTestSteps {
    static func menusEditClipboard(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let e = c.e
        let a = "    let a = 1;"
        let pasteboard = { NSPasteboard.general.string(forType: .string) ?? "nil" }
        return [
            c.step("menu undo", "Edit › Undo", prepare: {
                c.pasteboard = NSPasteboard.general.string(forType: .string)
                c.resetProbe()
                c.caret(on: "let a = 1", offset: 9)
                e.view?.breakUndoCoalescing()
                e.type("9")
                e.view?.breakUndoCoalescing()
            }) {
                (e.line(c.lineOf("let a = 1")) == a, "line '\(e.line(c.lineOf("let a = ")))'")
            },
            c.step("menu redo", "Edit › Redo") {
                (e.text.contains("let a = 19;"), "line '\(e.line(c.lineOf("let a = ")))'")
            },
            c.step("menu select all", "Edit › Select All", prepare: { c.resetProbe() }) {
                let range = e.view?.selectedRange() ?? NSRange()
                return (range.location == 0 && range.length == (e.text as NSString).length, "selected \(range)")
            },
            c.step("menu copy", "Edit › Copy", prepare: { c.select("hits: 0") }) {
                (pasteboard() == "hits: 0", "pasteboard \(pasteboard())")
            },
            c.step("menu cut line", "Edit › Cut", prepare: { c.caret(on: "let a = 1", offset: 2) }) {
                (!e.text.contains("let a = 1") && pasteboard() == a + "\n", "pasteboard \(pasteboard())")
            },
            c.step("menu paste", "Edit › Paste", prepare: { c.caret(on: "    let c = 3") }) {
                let al = c.lineOf("let a = 1")
                return (al > 0 && e.line(al + 1) == "    let c = 3;" && e.line(al - 1) == "    let b = 2;", "a at \(al): \(e.text)")
            },
            c.step("menu delete", "Edit › Delete", prepare: { c.select("hits: 0") }) {
                (!e.text.contains("hits: 0") && e.text.contains("MenuProbe {  }"), e.line(c.lineOf("let mut probe")))
            },
            SelfTestStep(name: "menu clipboard restore", run: {
                c.resetProbe()
                NSPasteboard.general.clearContents()
                if let saved = c.pasteboard {
                    NSPasteboard.general.setString(saved, forType: .string)
                }
            }, check: { e.expect(e.text == SelfTestMenuContext.probeSource, "probe not restored") }),
        ]
    }
}
