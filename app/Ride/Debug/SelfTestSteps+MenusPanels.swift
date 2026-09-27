import AppKit

extension SelfTestSteps {
    static func codeMenuPanels(state: AppState, e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        docSteps(e: e, stash: stash) + peekSteps(state: state, e: e, stash: stash) + signatureSteps(e: e, stash: stash)
    }

    private static var docs: DocController? {
        EditorPanes.shared.focused?.docs
    }

    private static var peek: PeekController? {
        EditorPanes.shared.focused?.peek
    }

    private static func pinButton(_ panel: NSPanel?) -> NSButton? {
        SelfTestViews.button(in: panel?.contentView) { $0.toolTip == "Pin" }
    }

    private static func docSteps(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        [
            SelfTestStep(name: "menu quick documentation", wait: 0.5, until: { docs?.html.contains("Adds two") == true }, timeout: 10, run: {
                e.activate()
                e.place(on: MenuBlock.call)
                SelfTestMenu.perform("Code › Quick Documentation")
            }, check: {
                e.expect(docs?.isVisible == true && docs?.html.contains("Adds two") == true, "visible \(docs?.isVisible ?? false) html \(docs?.html.prefix(120) ?? "")")
            }),
            SelfTestStep(name: "doc pin button", wait: 0.4, run: {
                let before = docs?.isVisible ?? false
                let clicked = SelfTestViews.click(in: docs?.panel.panel.contentView) { $0.toolTip == "Pin" }
                let after = pinButton(docs?.panel.panel)?.state == .on
                e.place(on: "menu_a * 3")
                stash.probe = "visible before \(before) clicked \(clicked) pinned \(after) visible after move \(docs?.isVisible ?? false)"
            }, check: {
                let state = pinButton(docs?.panel.panel)?.state
                return e.expect(docs?.isVisible == true && state == .on, "\(stash.probe) now visible \(docs?.isVisible ?? false) pin \(String(describing: state))")
            }),
            SelfTestStep(name: "doc escape", run: { SelfTestKey.escape.press(e.view) }, check: {
                e.expect(docs?.isVisible == false && pinButton(docs?.panel.panel)?.state == .off, "doc still visible")
            }),
        ]
    }

    private static func peekSteps(state: AppState, e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        [
            peekOpen("menu quick definition", e: e),
            SelfTestStep(name: "peek pin button", wait: 0.4, run: {
                _ = SelfTestViews.click(in: peek?.panel.panel.contentView) { $0.toolTip == "Pin" }
                e.place(on: "menu_a * 3")
            }, check: {
                let pin = pinButton(peek?.panel.panel)?.state
                return e.expect(peek?.isVisible == true && pin == .on, "visible \(peek?.isVisible ?? false) pin \(String(describing: pin))")
            }),
            SelfTestStep(name: "peek escape", run: { SelfTestKey.escape.press(e.view) }, check: {
                e.expect(peek?.isVisible == false, "peek still visible")
            }),
            peekOpen("peek reopen", e: e),
            SelfTestStep(name: "peek open button", wait: 0.5, until: { atDefinition(e) }, timeout: 10, run: {
                _ = SelfTestViews.click(in: peek?.panel.panel.contentView) { $0.title == "Open" }
            }, check: {
                e.expect(atDefinition(e) && peek?.isVisible != true, "caret line '\(e.line(e.caretLine))' peek \(peek?.isVisible ?? false)")
            }),
            SelfTestStep(name: "menu external documentation", wait: 0.5, until: { state.notice == DocController.noExternalNotice }, timeout: 10, run: {
                e.activate()
                e.place(on: "    menu_a * 3")
                SelfTestMenu.perform("Code › External Documentation")
            }, check: {
                e.expect(state.notice == DocController.noExternalNotice, "notice \(state.notice ?? "nil")")
            }),
        ]
    }

    private static func atDefinition(_ e: SelfTestEditor) -> Bool {
        let line = e.line(e.caretLine)
        return line.hasPrefix("fn _ride_menu(") || line.hasPrefix("/// Adds two")
    }

    private static func peekOpen(_ name: String, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { peek?.isVisible == true }, timeout: 10, run: {
            e.activate()
            e.place(on: MenuBlock.call)
            SelfTestMenu.perform("Code › Quick Definition")
        }, check: {
            e.expect(peek?.isVisible == true && peek?.excerptText.contains("fn _ride_menu") == true, "visible \(peek?.isVisible ?? false)")
        })
    }

    private static func signatureSteps(e: SelfTestEditor, stash: SelfTestStash) -> [SelfTestStep] {
        let help = SignatureHelpController.shared
        return [
            signatureOpen("menu signature help", e: e),
            SelfTestStep(name: "signature escape", run: { SelfTestKey.escape.press(e.view) }, check: {
                e.expect(!help.isVisible, "signature still visible")
            }),
            signatureOpen("signature reopen", e: e),
            SelfTestStep(name: "signature newline hides", run: { e.view?.insertNewline(nil) }, check: {
                e.expect(!help.isVisible, "signature still visible")
            }),
            SelfTestStep(name: "signature cleanup", run: { MenuBlock.reset(e, stash) }, check: {
                e.expect(e.lines.contains(MenuBlock.line) && e.text.contains(MenuBlock.call), "block missing")
            }),
        ]
    }

    private static func signatureOpen(_ name: String, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.5, until: { SignatureHelpController.shared.isVisible }, timeout: 10, run: {
            e.activate()
            e.place(on: MenuBlock.call)
            if let caret = e.view?.selectedRange().location {
                e.view?.setSelectedRange(NSRange(location: caret + "_ride_menu(".utf16.count, length: 0))
            }
            SelfTestMenu.perform("Code › Signature Help")
        }, check: {
            let help = SignatureHelpController.shared
            return e.expect(help.isVisible && help.activeName == "_ride_menu", "visible \(help.isVisible) name \(help.activeName ?? "nil")")
        })
    }
}
