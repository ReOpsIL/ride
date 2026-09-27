import AppKit

extension SelfTestSteps {
    static func codeMenuRefactor(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        [
            refactorStep("menu complete statement", "Code › Complete Statement", e: e, stash: stash, expect: ["    if input > 0 {"]) {
                MenuBlock.setLine(e, containing: "menu_a * 3", to: "    if input > 0")
                resync(e: e)
                e.place(on: "input > 0", atEnd: true)
            },
            refactorStep("menu extract variable", "Code › Extract Variable", e: e, stash: stash, expect: ["    let value = input + 2;"], selected: "value") {
                MenuBlock.select(e, "input + 2")
            },
            refactorStep("menu introduce constant", "Code › Introduce Constant", e: e, stash: stash, expect: ["const VALUE: i32 = 3;"], selected: "VALUE") {
                MenuBlock.select(e, "3", in: "menu_a * 3")
            },
            refactorStep("menu inline variable", "Code › Inline Variable", e: e, stash: stash, expect: ["    (input + 2) * 3"]) {
                e.place(on: "menu_a =")
            },
            foldStep("menu fold all", "Code › Fold All", e: e, stash: stash, reset: true) { $0 > 1 },
            foldStep("menu unfold all", "Code › Unfold All", e: e, stash: stash) { $0 == 0 },
            foldStep("menu fold", "Code › Fold", e: e, stash: stash, caret: "menu_a * 3") { $0 == 1 },
            foldStep("menu unfold", "Code › Unfold", e: e, stash: stash, caret: "menu_a * 3") { $0 == 0 },
        ]
    }

    static func codeMenuRestore(e: SelfTestEditor, stash: SelfTestStash) -> SelfTestStep {
        SelfTestStep(name: "menu restore", run: {
            MenuBlock.restore(e, stash)
        }, check: { e.expect(e.text == stash.original, "text not restored") })
    }

    private static func refactorStep(
        _ name: String,
        _ path: String,
        e: SelfTestEditor,
        stash: SelfTestStash,
        expect: [String],
        selected: String? = nil,
        prepare: @escaping () -> Void
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { expect.allSatisfy(e.lines.contains) }, timeout: 10, run: {
            MenuBlock.reset(e, stash)
            prepare()
            SelfTestMenu.perform(path)
        }, check: {
            e.expect(
                expect.allSatisfy(e.lines.contains) && (selected == nil || e.selectedText == selected),
                "selected '\(e.selectedText)' notice \(e.state.notice ?? "nil") block \(e.lines.suffix(8))"
            )
        })
    }

    private static func foldStep(
        _ name: String,
        _ path: String,
        e: SelfTestEditor,
        stash: SelfTestStash,
        reset: Bool = false,
        caret: String? = nil,
        wanted: @escaping (Int) -> Bool
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { wanted(e.view?.folds.ranges.count ?? -1) }, timeout: 10, run: {
            if reset {
                MenuBlock.reset(e, stash)
            }
            e.activate()
            if let caret {
                e.place(on: caret)
            }
            SelfTestMenu.perform(path)
        }, check: {
            e.expect(wanted(e.view?.folds.ranges.count ?? -1), "folds \(e.view?.folds.ranges.count ?? -1)")
        })
    }
}
