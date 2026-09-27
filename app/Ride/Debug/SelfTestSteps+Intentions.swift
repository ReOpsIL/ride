import AppKit

extension SelfTestSteps {
    static func rustIntentions(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        underscoreSteps(e: e, scratch: scratch) + constantIntentionSteps(e: e, scratch: scratch)
    }

    private static func underscoreSteps(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "intention prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                let at = e.lineRange(9).location
                view.setSelectedRange(NSRange(location: at, length: 0))
                view.insertText("    let unused = 1;\n", replacementRange: NSRange(location: at, length: 0))
                resync(e: e)
            }, check: { e.expect(e.line(9) == "    let unused = 1;", "line 9: '\(e.line(9))'") }),
            popupStep(
                "intention underscore",
                menu: "Code › Show Intention Actions",
                e: e,
                reset: {},
                pick: PopupCase(title: "Rename to _unused", expect: ["    let _unused = 1;"]) { e.caret(line: 9, column: 11) }
            ),
            SelfTestStep(name: "intention undo", until: { e.line(9) == "    let unused = 1;" }, timeout: 10, run: { e.undo() }, check: {
                e.expect(e.line(9) == "    let unused = 1;", "line 9: '\(e.line(9))'")
            }),
            restore(name: "intention cleanup", e: e, scratch: scratch),
        ]
    }

    private static func constantIntentionSteps(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "intention constant prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view else {
                    return
                }
                scratch.saved = view.string
                resync(e: e)
            }, check: { e.expect(!e.text.contains("VALUE"), "VALUE present") }),
            popupStep(
                "intention constant",
                menu: "Code › Show Intention Actions",
                e: e,
                reset: {},
                pick: PopupCase(title: "Introduce Constant", expect: ["const VALUE: &str = \"ride\";"]) {
                    MenuBlock.select(e, "\"ride\"")
                }
            ),
            restore(name: "intention constant cleanup", e: e, scratch: scratch),
        ]
    }
}
