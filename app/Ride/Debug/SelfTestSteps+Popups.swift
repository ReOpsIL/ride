import AppKit

struct PopupCase {
    let title: String
    let expect: [String]
    var selected: String?
    var prepare: () -> Void = {}
}

extension SelfTestSteps {
    static func popupStep(
        _ name: String,
        menu path: String,
        e: SelfTestEditor,
        reset: @escaping () -> Void,
        titles: [String]? = nil,
        pick: PopupCase
    ) -> SelfTestStep {
        let popup = SelfTestPopup.shared
        return SelfTestStep(name: name, wait: 0.5, until: { popup.done && pick.expect.allSatisfy(e.text.contains) }, timeout: 10, run: {
            reset()
            e.activate()
            pick.prepare()
            popup.arm(pick: pick.title)
            SelfTestMenu.perform(path)
        }, check: {
            popup.disarm()
            let listed = titles.map { $0 == popup.titles } ?? popup.titles.contains(pick.title)
            let missing = pick.expect.filter { !e.text.contains($0) }
            let selected = pick.selected.map { $0 == e.selectedText } ?? true
            return e.expect(
                popup.shown == 1 && listed && popup.picked == pick.title && missing.isEmpty && selected,
                "shown \(popup.shown) titles \(popup.titles) picked \(popup.picked ?? "nil") missing \(missing) selected '\(e.selectedText)'"
            )
        })
    }

    static func rustGeneratePopup(state: AppState, e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let block = "\nstruct GenMenu {\n    gx: i32,\n    gy: i32,\n}\n"
        let titles = ["new", "impl block", "Default impl", "Display impl"]
        let cases = [
            PopupCase(title: "new", expect: ["pub fn new(gx: i32, gy: i32) -> Self"]),
            PopupCase(title: "impl block", expect: ["impl GenMenu {}"]),
            PopupCase(title: "Default impl", expect: ["impl Default for GenMenu"]),
            PopupCase(title: "Display impl", expect: ["impl std::fmt::Display for GenMenu"]),
        ]
        return cases.map { item in
            var pick = item
            pick.prepare = { e.place(on: "gx: i32,") }
            return popupStep("generate popup \(item.title)", menu: "Code › Generate…", e: e, reset: { MenuBlock.reset(e, stash, block: block) }, titles: titles, pick: pick)
        }
    }

    static func surroundPopup(e: SelfTestEditor, stash: SelfTestStash, language: String, cases: [PopupCase], titles: [String], block: String) -> [SelfTestStep] {
        cases.map { pick in
            popupStep("surround \(language) \(pick.title)", menu: "Code › Surround With…", e: e, reset: { MenuBlock.reset(e, stash, block: block) }, titles: titles, pick: pick)
        }
    }

    static func rustSurroundPopup(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let line = "let menu_a = input + 2;"
        let word = { MenuBlock.select(e, "input", in: "input + 2") }
        let caret = { e.place(on: line) }
        let inline = { (title: String, open: String, close: String) in
            PopupCase(title: title, expect: ["    let menu_a = \(open)input\(close) + 2;"], selected: "input", prepare: word)
        }
        let block = { (title: String, head: String, selected: String) in
            PopupCase(title: title, expect: ["    \(head) {\n        \(line)\n    }"], selected: selected, prepare: caret)
        }
        let cases = [
            inline("{ … }", "{", "}"), inline("( … )", "(", ")"), inline("[ … ]", "[", "]"), inline("\" … \"", "\"", "\""),
            block("if", "if condition", "condition"), block("loop", "loop", "        " + line),
            block("unsafe", "unsafe", "        " + line), block("match", "match value", "value"),
            inline("Some( … )", "Some(", ")"), inline("Ok( … )", "Ok(", ")"), inline(blockOpen + " … " + blockClose, blockOpen + " ", " " + blockClose),
        ]
        return surroundPopup(e: e, stash: stash, language: "rust", cases: cases, titles: cases.map(\.title), block: MenuBlock.text)
    }
}
