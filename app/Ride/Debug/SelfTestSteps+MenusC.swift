import AppKit

extension SelfTestSteps {
    static let cMenuBlock = "\nint ride_menu(int input) {\n    int menu_a = input + 2;\n    return menu_a * 3;\n}\n"

    static func cMenuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let stash = SelfTestStash()
        return [
            SelfTestStep(name: "c menu prep", wait: 1.0, run: {
                MenuBlock.open(state: state, e: e, stash: stash, file: "src/main.c")
                MenuBlock.reset(e, stash, block: cMenuBlock)
            }, check: { e.expect(e.lines.contains("    int menu_a = input + 2;"), "no c menu block") }),
            gateStep(
                "c code menu gates",
                e: e,
                enabled: CodeMenuPaths.editor + CodeMenuPaths.language + ["Build › Check", "Build › Check Project"],
                disabled: CodeMenuPaths.rustAndCpp
            ),
        ] + cSurroundPopup(e: e, stash: stash) + cCheckSteps(state: state, e: e, stash: stash)
    }

    private static func cSurroundPopup(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let line = "int menu_a = input + 2;"
        let word = { MenuBlock.select(e, "input", in: "input + 2") }
        let caret = { e.place(on: line) }
        let inline = { (title: String, open: String, close: String) in
            PopupCase(title: title, expect: ["    int menu_a = \(open)input\(close) + 2;"], selected: "input", prepare: word)
        }
        let block = { (title: String, head: String, body: String, close: String, selected: String) in
            PopupCase(title: title, expect: ["    \(head)\n\(body)\(line)\n    \(close)"], selected: selected, prepare: caret)
        }
        let cases = [
            inline("{ … }", "{", "}"), inline("( … )", "(", ")"), inline("[ … ]", "[", "]"), inline("\" … \"", "\"", "\""),
            block("if", "if (condition) {", "        ", "}", "condition"),
            block("while", "while (condition) {", "        ", "}", "condition"),
            block("#if 0 … #endif", "#if 0", "    ", "#endif", "    " + line),
            inline(blockOpen + " … " + blockClose, blockOpen + " ", " " + blockClose),
        ]
        return surroundPopup(e: e, stash: stash, language: "c", cases: cases, titles: cases.map(\.title), block: cMenuBlock)
    }

    private static func cCheckSteps(state: AppState, e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let broken = cMenuBlock.replacingOccurrences(of: "input + 2;", with: "input + ride_check_zz;")
        let file = { state.activeBuffer?.fileURL }
        return [
            SelfTestStep(name: "c menu check prep", wait: 0.5, run: {
                MenuBlock.reset(e, stash, block: broken)
                state.saveActive()
            }, check: { e.expect(state.activeBuffer?.isDirty == false && e.text.contains("ride_check_zz"), "broken block not saved") }),
            checkMenuStep("menu check clang", "Build › Check", state: state, e: e, stash: stash) {
                file().map(CheckPlan.clangFile)
            },
            SelfTestStep(name: "c check reports the error", run: {}, check: {
                let hit = CheckService.shared.diagnostics.contains { $0.message.contains("ride_check_zz") }
                return e.expect(hit, "diagnostics \(CheckService.shared.diagnostics.map(\.message).prefix(4))")
            }),
            checkMenuStep("menu check project clang", "Build › Check Project", state: state, e: e, stash: stash) {
                state.activeCheckProject.map { CheckPlan.clangProject(root: $0.root) }
            },
            SelfTestStep(name: "c menu restore", wait: 0.5, run: {
                MenuBlock.restore(e, stash)
                state.saveActive()
            }, check: { e.expect(e.text == stash.original && state.activeBuffer?.isDirty == false, "main.c not restored") }),
        ]
    }
}
