import AppKit

extension SelfTestSteps {
    static func prefPopupSteps(state: AppState, e: SelfTestEditor, bind: PreferenceBindings, p: PrefScratch) -> [SelfTestStep] {
        [
            typedPopupStep("pref completions off", e: e, p: p, keep: true, set: { bind.bool(\.completions).wrappedValue = false }, typed: ".", wait: 1.5) {
                let auto = CompletionSession.shared.isVisible
                if let view = e.view {
                    CompletionSession.shared.trigger(view: view)
                }
                return auto ? "popup opened while typing" : nil
            },
            SelfTestStep(name: "pref completions off still triggers", until: { CompletionSession.shared.isVisible }, timeout: 6, run: {}, check: {
                let shown = CompletionSession.shared.isVisible
                untype(e, p)
                bind.bool(\.completions).wrappedValue = true
                return e.expect(shown, "explicit completion did not open")
            }),
            typedPopupStep("pref completions on", e: e, p: p, set: {}, typed: ".", until: { CompletionSession.shared.isVisible }) {
                CompletionSession.shared.isVisible ? nil : "popup did not open while typing"
            },
            typedPopupStep("pref cheat sheet off", e: e, p: p, set: { bind.bool(\.cheatSheet).wrappedValue = false }, typed: ".", until: { CompletionSession.shared.isVisible }) {
                CheatSheetController.shared.isVisible ? "cheat sheet followed completions" : nil
            },
            SelfTestStep(name: "pref cheat sheet on", wait: 0.3, run: { bind.bool(\.cheatSheet).wrappedValue = true }, check: {
                e.expect(state.prefs.cheatSheet && !CheatSheetController.shared.isVisible, "cheat sheet state")
            }),
            typedPopupStep("pref signature help off", e: e, p: p, set: { bind.bool(\.signatureHelp).wrappedValue = false }, typed: Self.signatureCall, wait: 1.5) {
                SignatureHelpController.shared.isVisible ? "signature help shown" : nil
            },
            typedPopupStep("pref signature help on", e: e, p: p, set: { bind.bool(\.signatureHelp).wrappedValue = true }, typed: Self.signatureCall, until: { SignatureHelpController.shared.isVisible }) {
                SignatureHelpController.shared.isVisible ? nil : "signature help missing"
            },
            SelfTestStep(name: "doc overlay ignores the pointer", wait: 0.4, run: {
                HoverController.shared.hide()
                movePointer(e, over: "Counter::new")
            }, check: {
                HoverController.shared.isVisible ? "card shown" : nil
            }),
            SelfTestStep(name: "doc overlay on quick documentation", wait: 0.3, until: { HoverController.shared.isVisible }, timeout: 8, run: {
                HoverController.shared.hide()
                e.place(on: "Counter::new")
                state.showQuickDocumentation()
            }, check: {
                HoverController.shared.isVisible ? nil : "card missing"
            }),
            SelfTestStep(name: "hover click opens docs", wait: 0.8, run: { p.flag = HoverController.shared.upgradeIfVisible() }, check: {
                let docs = EditorPanes.shared.focused?.docsStorage?.isVisible == true
                EditorPanes.shared.focused?.docsStorage?.hide()
                return e.expect(p.flag && docs && !HoverController.shared.isVisible, "upgraded \(p.flag) docs \(docs)")
            }),
        ]
    }

    static let signatureName = "_ride_sig("
    static let signatureCall = "\nfn _ride_sig(a: i32, b: i32) {}\nfn _ride_sig_call() { " + signatureName

    private static func untype(_ e: SelfTestEditor, _ p: PrefScratch) {
        CompletionSession.shared.hide()
        SignatureHelpController.shared.hide()
        CheatSheetController.shared.close()
        guard let view = e.view else {
            return
        }
        let added = (view.string as NSString).length - p.typedLength
        guard added > 0, p.typedAt + added <= (view.string as NSString).length else {
            return
        }
        view.replaceText(in: NSRange(location: p.typedAt, length: added), with: "")
    }

    private static func typedPopupStep(
        _ name: String,
        e: SelfTestEditor,
        p: PrefScratch,
        keep: Bool = false,
        set: @escaping () -> Void,
        typed: String,
        wait: Double = 0.3,
        until: (() -> Bool)? = nil,
        check: @escaping () -> String?
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: wait, until: until, timeout: until == nil ? 0 : 6, run: {
            set()
            e.activate()
            CompletionSession.shared.hide()
            let freeStanding = typed.hasPrefix("\n")
            if freeStanding, let view = e.view {
                view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
            } else {
                e.place(on: "counter.record(\"ride\");", atEnd: true)
            }
            let text = freeStanding ? typed : "\n    counter" + typed
            p.typedAt = e.view?.selectedRange().location ?? 0
            p.typedLength = ((e.view?.string ?? "") as NSString).length
            if freeStanding, let view = e.view {
                let prefix = String(text.dropLast(Self.signatureName.count))
                view.insertText(prefix, replacementRange: NSRange(location: p.typedAt, length: 0))
                view.setSelectedRange(NSRange(location: p.typedAt + (prefix as NSString).length, length: 0))
                e.type(Self.signatureName)
            } else {
                e.type(text)
            }
        }, check: {
            let failure = check()
            if !keep {
                untype(e, p)
            }
            return failure
        })
    }

    private static func movePointer(_ e: SelfTestEditor, over needle: String) {
        guard let view = e.view, let window = view.window else {
            return
        }
        let text = view.string as NSString
        let range = text.range(of: needle)
        guard range.location != NSNotFound else {
            return
        }
        let rect = SelfTestPixels.rect(of: NSRange(location: range.location + 2, length: 1), in: view)
        let point = view.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil)
        guard let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) else {
            return
        }
        view.mouseMoved(with: event)
    }
}
