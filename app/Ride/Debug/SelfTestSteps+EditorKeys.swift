import AppKit

final class EditorKeysScratch {
    var pasteboard: String?
    var copied = ""
    var posted = false
}

extension SelfTestSteps {
    static func editorKeySteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let k = EditorKeysScratch()
        let pasteboard = NSPasteboard.general
        let restore = {
            pasteboard.clearContents()
            if let saved = k.pasteboard {
                pasteboard.setString(saved, forType: .string)
            }
        }
        return [
            SelfTestStep(name: "copy line without selection", run: {
                k.pasteboard = pasteboard.string(forType: .string)
                e.place(on: "mod util;")
                e.view?.copy(nil)
                k.copied = pasteboard.string(forType: .string) ?? ""
            }, check: {
                restore()
                return e.expect(k.copied == "mod util;\n", "copied \(k.copied.debugDescription)")
            }),
            SelfTestStep(name: "cut line without selection", run: {
                k.pasteboard = pasteboard.string(forType: .string)
                e.place(on: "mod util;")
                e.view?.cut(nil)
                k.copied = pasteboard.string(forType: .string) ?? ""
            }, check: {
                let removed = !e.text.contains("mod util;")
                e.undo()
                restore()
                return e.expect(k.copied == "mod util;\n" && removed && e.text.hasPrefix("mod util;"), "cut \(k.copied.debugDescription) removed \(removed)")
            }),
            SelfTestStep(name: "completion shift arrow selects text", until: {
                if !k.posted, CompletionSession.shared.isVisible {
                    k.posted = SelfTestKeys.post("⇧↓", window: SelfTestKeys.mainWindow)
                }
                return k.posted && (e.view?.selectedRange().length ?? 0) > 0
            }, timeout: 6, run: {
                k.posted = false
                e.activate()
                e.place(on: "Counter::new")
                e.view.map { $0.setSelectedRange(NSRange(location: $0.selectedRange().location + 3, length: 0)) }
                e.view.map(CompletionSession.shared.trigger(view:))
            }, check: {
                let length = e.view?.selectedRange().length ?? 0
                CompletionSession.shared.hide()
                e.place(on: "Counter::new")
                return e.expect(k.posted && length > 0, "posted \(k.posted) selection \(length)")
            }),
            SelfTestStep(name: "cmd click goes to definition", until: { state.activeBuffer?.fileURL?.lastPathComponent != "main.rs" }, timeout: 8, run: {
                commandClick(on: "counter.record", offset: 10, e: e)
                let caret = e.view?.selectedRange().location ?? 0
                k.copied = e.view.flatMap { IdentifierRange.at($0.string as NSString, index: caret) }.map { (e.text as NSString).substring(with: $0) } ?? "-"
            }, check: {
                let file = state.activeBuffer?.fileURL?.lastPathComponent ?? "-"
                state.goBack()
                return e.expect(file != "main.rs" && k.copied == "record", "opened \(file) clicked '\(k.copied)'")
            }),
        ] + foldInOtherPaneSteps(state: state, e: e)
    }

    private static func commandClick(on needle: String, offset: Int, e: SelfTestEditor) {
        guard let view = e.view, let window = view.window else {
            return
        }
        let range = (view.string as NSString).range(of: needle)
        guard range.location != NSNotFound else {
            return
        }
        let rect = SelfTestPixels.rect(of: NSRange(location: range.location + offset, length: 1), in: view)
        let point = view.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil)
        if let event = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: .command, timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
            view.mouseDown(with: event)
        }
    }

    private static func foldInOtherPaneSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let otherView = { EditorPanes.shared.all.map(\.textView).first { $0 !== e.view && $0.window != nil && $0.string.contains("struct Counter") } }
        let setup = SelfTestStep(name: "split util beside main", until: { otherView() != nil && e.text.contains("fn main()") }, timeout: 4, run: {
            let root = state.workspaceRoot ?? URL(fileURLWithPath: "/")
            state.openFile(root.appendingPathComponent("src/util.rs"))
            let util = state.activeBuffer
            state.openFile(root.appendingPathComponent("src/main.rs"))
            let main = state.activeBuffer
            util.map { state.openInSplit($0.id) }
            main.map { state.selectBuffer($0.id) }
        }, check: { e.expect(otherView() != nil && e.text.contains("fn main()"), "split views missing") })
        return [setup, foldInOtherPane(state: state, e: e, otherView: otherView)]
    }

    private static func foldInOtherPane(state: AppState, e: SelfTestEditor, otherView: @escaping () -> RideTextView?) -> SelfTestStep {
        var other: RideTextView?
        return SelfTestStep(name: "gutter fold acts on its own pane", until: {
            guard let other else {
                return true
            }
            if other.folds.isEmpty {
                FoldController.shared.refreshStarts(other)
                if let line = (1...other.lineIndex().starts.count).first(where: { other.folds.isFoldStart(line: $0) }) {
                    FoldController.shared.toggle(line: line, in: other)
                }
            }
            return !other.folds.isEmpty
        }, timeout: 6, run: {
            other = otherView()
        }, check: {
            let folded = other?.folds.isEmpty == false
            let mainFolded = EditorPanes.shared.all.map(\.textView).contains { $0.string.contains("fn main()") && !$0.folds.isEmpty }
            if let other, other.window?.makeFirstResponder(other) == true {
                FoldController.shared.unfoldAll()
            }
            state.closeSplit()
            state.openFile((state.workspaceRoot ?? URL(fileURLWithPath: "/")).appendingPathComponent("src/main.rs"))
            e.focus()
            return e.expect(other != nil && folded && !mainFolded, "other pane \(other != nil) folded \(folded) main folded \(mainFolded)")
        })
    }
}
