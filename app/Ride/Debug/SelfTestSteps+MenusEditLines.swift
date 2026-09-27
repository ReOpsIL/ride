import AppKit

extension SelfTestSteps {
    static func menusEditLines(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let e = c.e
        let a = "    let a = 1;"
        let b = "    let b = 2;"
        let cLine = "    let c = 3;"
        let lines = { (c.lineOf("let b = 2"), c.lineOf("let a = 1"), c.lineOf("let c = 3")) }
        let atA = { c.resetProbe(); c.caret(on: "let a = 1", offset: 2) }
        return [
            SelfTestStep(name: "menu probe open", wait: 1.0, until: {
                c.state.activeBuffer?.sessionId != nil && c.shows(c.probeURL)
            }, timeout: 15, run: { c.openProbe() }, check: {
                e.expect(c.activeName == "menu_probe.rs" && e.text == SelfTestMenuContext.probeSource, "active \(c.activeName)")
            }),
            c.step("menu duplicate line", "Edit › Duplicate Line", prepare: atA) {
                let (_, al, _) = lines()
                return (e.line(al) == a && e.line(al + 1) == a, "\(e.line(al)) | \(e.line(al + 1))")
            },
            c.step("menu delete line", "Edit › Delete Line", prepare: atA) {
                (!e.text.contains("let a = 1") && e.text.contains(cLine), e.text)
            },
            c.step("menu join lines", "Edit › Join Lines", prepare: { c.resetProbe(); c.caret(on: "let b = 2") }) {
                let bl = c.lineOf("let b = 2")
                return (e.line(bl).hasPrefix(b) && e.line(bl).hasSuffix("let a = 1;"), e.line(bl))
            },
            c.step("menu move line up", "Edit › Move Line Up", prepare: atA) {
                let (bl, al, _) = lines()
                return (al + 1 == bl, "a \(al) b \(bl)")
            },
            c.step("menu move line down", "Edit › Move Line Down", prepare: atA) {
                let (_, al, cl) = lines()
                return (cl + 1 == al, "a \(al) c \(cl)")
            },
            c.step("menu move statement up", "Edit › Move Statement Up", wait: 0.5, prepare: atA) {
                let (bl, al, _) = lines()
                return (al + 1 == bl, "a \(al) b \(bl)")
            },
            c.step("menu move statement down", "Edit › Move Statement Down", wait: 0.5, prepare: atA) {
                let (_, al, cl) = lines()
                return (cl + 1 == al, "a \(al) c \(cl)")
            },
            c.step("menu start new line", "Edit › Start New Line", prepare: atA) {
                let al = c.lineOf("let a = 1")
                return (e.line(al + 1).trimmingCharacters(in: .whitespaces).isEmpty && e.caretLine == al + 1 && e.line(al + 2) == cLine, "caret \(e.caretLine) next '\(e.line(al + 1))'")
            },
            c.step("menu start new line before", "Edit › Start New Line Before", prepare: atA) {
                let al = c.lineOf("let a = 1")
                return (e.line(al - 1).trimmingCharacters(in: .whitespaces).isEmpty && e.caretLine == al - 1 && e.line(al - 2) == b, "caret \(e.caretLine) prev '\(e.line(al - 1))'")
            },
            c.step("menu toggle case", "Edit › Toggle Case", prepare: { c.resetProbe(); c.caret(on: "menu_lines", offset: 3) }) {
                (e.text.contains("fn MENU_LINES()"), e.line(c.lineOf("fn ")))
            },
            c.step("menu sort lines", "Edit › Sort Lines", prepare: {
                c.resetProbe()
                let bl = c.lineOf("let b = 2")
                e.selectLines(bl, bl + 2)
            }) {
                let (bl, al, cl) = lines()
                return (al < bl && bl < cl, "a \(al) b \(bl) c \(cl)")
            },
            c.step("menu select line", "Edit › Select Line", prepare: atA) {
                (e.selectedText == a + "\n", "selected '\(e.selectedText)'")
            },
            c.step("menu select word", "Edit › Select Word", prepare: { c.resetProbe(); c.caret(on: "probe = ", offset: 2) }) {
                (e.selectedText == "probe", "selected '\(e.selectedText)'")
            },
            c.step("menu extend selection", "Edit › Extend Selection", wait: 0.5) {
                (e.selectedText.count > 5 && e.selectedText.contains("probe"), "selected '\(e.selectedText)'")
            },
            c.step("menu shrink selection", "Edit › Shrink Selection") {
                (e.selectedText == "probe", "selected '\(e.selectedText)'")
            },
            c.step("menu copy reference", "Edit › Copy Reference", prepare: atA) {
                let expected = "src/menu_probe.rs:\(c.lineOf("let a = 1"))"
                let copied = NSPasteboard.general.string(forType: .string) ?? "nil"
                return (copied == expected, "pasteboard \(copied) want \(expected)")
            },
        ]
    }
}
