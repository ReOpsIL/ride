import AppKit

private enum DocWebViewRelease {
    static weak var probe: DocWebView?
}

extension SelfTestSteps {
    static func quickDocOpen(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick doc open", wait: 0.8, run: {
            if let main = state.workspaceRoot?.appendingPathComponent("src/main.rs") {
                state.openFile(main)
            }
        }, check: {
            e.expect(e.text.contains("Counter"), "no Counter")
        })
    }

    static func quickDoc(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick doc", wait: 1.2, run: {
            placeCaret(e, on: "Counter")
            state.showQuickDocumentation()
        }, check: {
            docExpect(e, visible: true, contains: ["<h1>", "Counter"])
        })
    }

    static func completionDocTrigger(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "completion doc trigger", wait: 1.0, run: {
            EditorPanes.shared.focused?.closeDocs()
            e.focus()
            openCompletionOnCou(e)
        }, check: {
            let popup = CompletionSession.shared.popup
            let hit = popup.hitNamed("Counter") ?? CompletionSession.shared.list?.base.first { $0.name == "Counter" }
            return e.expect(
                CompletionSession.shared.isVisible && hit?.name == "Counter",
                "completion \(CompletionSession.shared.isVisible) hit \(hit?.name ?? "nil")"
            )
        })
    }

    static func completionDoc(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "completion doc", wait: 1.2, run: {
            if let view = e.view {
                DocController.showCompletion(in: view, name: "Counter")
            }
        }, check: {
            docExpect(e, visible: true, contains: ["<h1>", "Counter"])
        })
    }

    static func docCleanup() -> SelfTestStep {
        SelfTestStep(name: "doc cleanup", wait: 0.2, run: {
            EditorPanes.shared.focused?.closeDocs()
            CompletionSession.shared.hide()
        }, check: { nil })
    }

    static func docWebViewReleases(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "doc webview releases", wait: 0.3, run: {
            autoreleasepool {
                var web: DocWebView? = DocWebView()
                DocWebViewRelease.probe = web
                web = nil
            }
        }, check: {
            let leaked = DocWebViewRelease.probe != nil
            DocWebViewRelease.probe = nil
            return e.expect(!leaked, "webview still alive")
        })
    }

    static func quickDefinition(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "quick definition", wait: 1.2, run: {
            placeCaret(e, on: "record")
            state.showQuickDefinition()
        }, check: {
            let peek = EditorPanes.shared.focused?.peek
            let text = peek?.excerptText ?? ""
            let labels = peek?.labels ?? []
            return e.expect(
                peek?.isVisible == true && text.contains("fn record") && labels.count == 2,
                "visible \(peek?.isVisible ?? false) labels \(labels) text \(text.prefix(160))"
            )
        })
    }

    static func peekCleanup() -> SelfTestStep {
        SelfTestStep(name: "peek cleanup", wait: 0.2, run: {
            EditorPanes.shared.focused?.closeDocs()
        }, check: { nil })
    }

    static func docPin(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "doc pin", wait: 0.4, run: {
            EditorPanes.shared.focused?.docs.pin()
            placeCaret(e, on: "main")
        }, check: {
            docExpect(e, visible: true, contains: ["<h1>"])
        })
    }

    private static func placeCaret(_ e: SelfTestEditor, on needle: String, atEnd: Bool = false) {
        guard let view = e.view else {
            return
        }
        let range = (view.string as NSString).range(of: needle)
        guard range.location != NSNotFound else {
            return
        }
        let loc = atEnd ? NSMaxRange(range) : range.location
        view.setSelectedRange(NSRange(location: loc, length: 0))
    }

    private static func openCompletionOnCou(_ e: SelfTestEditor) {
        guard let view = e.view else {
            return
        }
        let range = (view.string as NSString).range(of: "Counter::new")
        if range.location != NSNotFound {
            view.setSelectedRange(NSRange(location: range.location + 3, length: 0))
            CompletionSession.shared.trigger(view: view)
            return
        }
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        e.type("\nCou")
    }

    private static func docExpect(_ e: SelfTestEditor, visible: Bool, contains: [String]) -> String? {
        let docs = EditorPanes.shared.focused?.docs
        let html = docs?.html ?? ""
        let shown = docs?.isVisible ?? false
        let missing = contains.filter { !html.contains($0) }
        return e.expect(
            shown == visible && missing.isEmpty,
            "visible \(shown) missing \(missing) html \(html.prefix(200))"
        )
    }
}
