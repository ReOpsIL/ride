import AppKit

enum MenuBlock {
    static let text = "\n/// Adds two to the input.\nfn _ride_menu(input: i32) -> i32 {\n    let menu_a = input + 2;\n    menu_a * 3\n}\n\nfn _ride_menu_use() -> i32 {\n    _ride_menu(1)\n}\n"
    static let call = "_ride_menu(1)"
    static let line = "    let menu_a = input + 2;"

    static func open(state: AppState, e: SelfTestEditor, stash: SelfTestStash, file: String, base: String? = nil) {
        if let url = state.workspaceRoot?.appendingPathComponent(file) {
            state.openFile(url)
            e.activate()
            stash.original = e.text
            stash.base = base ?? (try? String(contentsOf: url, encoding: .utf8)) ?? e.text
        }
    }

    static func reset(_ e: SelfTestEditor, _ stash: SelfTestStash, block: String = text) {
        replaceAll(e, with: stash.base + block)
    }

    static func restore(_ e: SelfTestEditor, _ stash: SelfTestStash) {
        replaceAll(e, with: stash.original)
    }

    static func replaceAll(_ e: SelfTestEditor, with text: String) {
        e.activate()
        guard let view = e.view else {
            return
        }
        view.insertText(text, replacementRange: NSRange(location: 0, length: (view.string as NSString).length))
        SelfTestSteps.resync(e: e)
    }

    static func setLine(_ e: SelfTestEditor, containing needle: String, to text: String) {
        guard let number = e.lines.firstIndex(where: { $0.contains(needle) }).map({ $0 + 1 }) else {
            return
        }
        var range = e.lineRange(number)
        if (e.text as NSString).substring(with: range).hasSuffix("\n") {
            range.length -= 1
        }
        e.view?.insertText(text, replacementRange: range)
        e.caret(line: number, column: 1)
    }

    static func line(_ e: SelfTestEditor, containing needle: String) -> String {
        e.lines.first { $0.contains(needle) } ?? "<missing \(needle)>"
    }

    static func select(_ e: SelfTestEditor, _ needle: String, in context: String) {
        guard let view = e.view else {
            return
        }
        let outer = (view.string as NSString).range(of: context)
        guard outer.location != NSNotFound else {
            return
        }
        let inner = (context as NSString).range(of: needle)
        view.setSelectedRange(NSRange(location: outer.location + inner.location, length: inner.length))
    }

    static func select(_ e: SelfTestEditor, _ needle: String) {
        guard let view = e.view else {
            return
        }
        let range = (view.string as NSString).range(of: needle)
        if range.location != NSNotFound {
            view.setSelectedRange(range)
        }
    }
}

extension SelfTestSteps {
    static func codeMenuRust(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let stash = SelfTestStash()
        return codeMenuEditing(state: state, e: e, stash: stash)
            + codeMenuRefactor(e: e, stash: stash)
            + codeMenuAssist(e: e, stash: stash)
            + codeMenuPanels(state: state, e: e, stash: stash)
            + rustGeneratePopup(state: state, e: e, stash: stash)
            + rustSurroundPopup(e: e, stash: stash)
            + rustBuildMenu(state: state, e: e, stash: stash)
            + [codeMenuRestore(e: e, stash: stash)]
            + rustGateSteps(state: state, e: e)
    }

    static func codeMenuEditing(state: AppState, e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        [
            SelfTestStep(name: "menu prep", wait: 1.0, run: {
                MenuBlock.open(state: state, e: e, stash: stash, file: "src/main.rs", base: "fn main() {\n    println!(\"menu\");\n}\n")
                MenuBlock.reset(e, stash)
            }, check: { e.expect(e.lines.contains(MenuBlock.line), "no menu block") }),
            menuLineStep("menu comment line", "Code › Comment Line", e: e, expect: "    // let menu_a = input + 2;") { e.place(on: "let menu_a") },
            menuLineStep("menu uncomment line", "Code › Comment Line", e: e, expect: MenuBlock.line) {},
            menuLineStep("menu comment block", "Code › Comment Block", e: e, expect: "    " + blockOpen + " let menu_a = input + 2; " + blockClose) {
                MenuBlock.select(e, "let menu_a = input + 2;")
            },
            menuLineStep("menu uncomment block", "Code › Comment Block", e: e, expect: MenuBlock.line) {},
            menuLineStep("menu indent", "Code › Indent", e: e, expect: "    " + MenuBlock.line) { e.place(on: "let menu_a") },
            menuLineStep("menu unindent", "Code › Unindent", e: e, expect: MenuBlock.line) {},
            menuLineStep("menu auto-indent", "Code › Auto-Indent Lines", e: e, expect: MenuBlock.line) {
                MenuBlock.setLine(e, containing: "menu_a =", to: "let menu_a = input + 2;")
            },
            formatStep("menu reformat selection", "Code › Reformat Selection", e: e, messy: "    let menu_a =   input+2;") {
                MenuBlock.select(e, "let menu_a =   input+2;")
            },
            formatStep("menu reformat document", "Code › Reformat Document", e: e, messy: "    let   menu_a = input + 2;") {},
        ]
    }

    static func menuLineStep(
        _ name: String,
        _ path: String,
        e: SelfTestEditor,
        expect: String,
        prepare: @escaping () -> Void
    ) -> SelfTestStep {
        SelfTestStep(name: name, run: {
            e.activate()
            prepare()
            SelfTestMenu.perform(path)
        }, check: {
            e.expect(e.lines.contains(expect), "wanted '\(expect)' got '\(MenuBlock.line(e, containing: "menu_a ="))'")
        })
    }

    private static func formatStep(
        _ name: String,
        _ path: String,
        e: SelfTestEditor,
        messy: String,
        select: @escaping () -> Void
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { e.lines.contains(MenuBlock.line) }, timeout: 30, run: {
            e.activate()
            MenuBlock.setLine(e, containing: "menu_a =", to: messy)
            select()
            SelfTestMenu.perform(path)
        }, check: {
            e.expect(
                e.lines.contains(MenuBlock.line) && e.state.formatError == nil,
                "line '\(MenuBlock.line(e, containing: "menu_a"))' error \(e.state.formatError ?? "-")"
            )
        })
    }
}
