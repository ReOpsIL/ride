import AppKit

enum SelfTestSteps {
    static let blockOpen = "/" + "*"
    static let blockClose = "*" + "/"

    static func all(state: AppState) -> [SelfTestStep] {
        let e = SelfTestEditor(state: state)
        return [
            SelfTestStep(name: "setup", wait: 1.5, run: { e.focus() }, check: { e.expect(e.view != nil && e.lines.count > 15, "editor missing") }),
            SelfTestStep(name: "indent keeps selection", run: { e.selectLines(10, 10); e.view?.insertTab(nil) }, check: {
                e.expect(e.line(10).hasPrefix("        counter") && (e.view?.selectedRange().length ?? 0) > 0, "line 10: \(e.line(10)) sel \(String(describing: e.view?.selectedRange()))")
            }),
            SelfTestStep(name: "unindent keeps selection", run: { e.view?.insertBacktab(nil) }, check: {
                e.expect(e.line(10).hasPrefix("    counter") && (e.view?.selectedRange().length ?? 0) > 0, "line 10: \(e.line(10))")
            }),
            SelfTestStep(name: "tab inserts spaces", run: { e.caret(line: 10, column: 5); e.view?.insertTab(nil) }, check: {
                e.expect(e.line(10).hasPrefix("        counter"), "line 10: \(e.line(10))")
            }),
            SelfTestStep(name: "undo is one step", run: { e.view?.undoManager?.undo() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "comment line", run: { e.caret(line: 10); EditorCommands.commentLine() }, check: { e.expect(e.line(10) == "    // counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "uncomment line", run: { EditorCommands.commentLine() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "comment block", run: { e.selectLines(10, 11); EditorCommands.commentBlock() }, check: { e.expect(e.line(10) == "    " + blockOpen + " counter.record(\"ride\");" && e.line(11).hasSuffix("\"engine\"); " + blockClose), "\(e.line(10)) | \(e.line(11))") }),
            SelfTestStep(name: "uncomment block", run: { EditorCommands.commentBlock() }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");" && e.line(11) == "    counter.record(\"engine\");", "\(e.line(10)) | \(e.line(11))") }),
            SelfTestStep(name: "duplicate line", run: { e.caret(line: 10); EditorCommands.duplicate() }, check: { e.expect(e.line(11) == e.line(10) && e.line(10).contains("ride"), "line 11: \(e.line(11))") }),
            SelfTestStep(name: "delete line", run: { EditorCommands.deleteLines() }, check: { e.expect(e.line(11).contains("engine"), "line 11: \(e.line(11))") }),
            SelfTestStep(name: "join lines", run: { e.caret(line: 9); EditorCommands.joinLines() }, check: { e.expect(e.line(9).contains("new(); counter.record"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "undo join", run: { e.view?.undoManager?.undo() }, check: { e.expect(e.line(10).contains("ride") && !e.line(9).contains("record"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "move line down", run: { e.caret(line: 10); EditorCommands.moveLines(up: false) }, check: { e.expect(e.line(11).contains("ride") && e.line(10).contains("engine"), "\(e.line(10)) | \(e.line(11))") }),
            SelfTestStep(name: "move line up", run: { EditorCommands.moveLines(up: true) }, check: { e.expect(e.line(10).contains("ride") && e.caretLine == 10, "\(e.line(10)) caret \(e.caretLine)") }),
            SelfTestStep(name: "new line after", run: { e.caret(line: 10, column: 3); EditorCommands.newLine(before: false) }, check: { e.expect(e.line(11) == "    " && e.caretLine == 11, "line 11: '\(e.line(11))' caret \(e.caretLine)") }),
            SelfTestStep(name: "new line before", run: { EditorCommands.deleteLines(); e.caret(line: 10, column: 6); EditorCommands.newLine(before: true) }, check: { e.expect(e.line(10) == "    " && e.line(11).contains("ride"), "line 10: '\(e.line(10))'") }),
            SelfTestStep(name: "toggle case", run: { EditorCommands.deleteLines(); e.caret(line: 10, column: 7); EditorCommands.toggleCase() }, check: { e.expect(e.line(10).contains("COUNTER.record"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "toggle case back", run: { EditorCommands.toggleCase() }, check: { e.expect(e.line(10).contains("counter.record"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "sort lines", run: { e.selectLines(10, 12); EditorCommands.sortLines() }, check: { e.expect(e.line(10).contains("engine"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "undo sort", run: { e.view?.undoManager?.undo() }, check: { e.expect(e.line(10).contains("ride") && e.line(11).contains("engine"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "select word", run: { e.caret(line: 10, column: 14); EditorCommands.selectWord() }, check: { e.expect(e.selectedText == "record", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "extend selection", run: { EditorCommands.extendSelection() }, check: { e.expect(e.selectedText.count > 6 && e.selectedText.contains("record"), "selected: \(e.selectedText)") }),
            SelfTestStep(name: "shrink selection", run: { EditorCommands.shrinkSelection() }, check: { e.expect(e.selectedText == "record", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "select line", run: { EditorCommands.selectLine() }, check: { e.expect(e.selectedText.hasSuffix("\n") && e.selectedText.contains("ride"), "selected: \(e.selectedText)") }),
            SelfTestStep(name: "matching brace", run: { e.caret(line: 8, column: 12); EditorCommands.matchingBrace() }, check: { e.expect(e.caretLine == 20, "caret \(e.caretLine)") }),
            SelfTestStep(name: "smart newline", run: { e.caret(line: 8, column: 12); e.view?.insertNewline(nil) }, check: { e.expect(e.line(9) == "    " && e.caretLine == 9, "line 9: '\(e.line(9))' caret \(e.caretLine)") }),
            SelfTestStep(name: "closing brace dedent", run: { e.view?.insertText("}", replacementRange: NSRange(location: NSNotFound, length: 0)) }, check: { e.expect(e.line(9) == "}", "line 9: '\(e.line(9))'") }),
            SelfTestStep(name: "cleanup brace", run: { EditorCommands.deleteLines() }, check: { e.expect(e.line(9).contains("Counter::new"), "line 9: \(e.line(9))") }),
            SelfTestStep(name: "bracket pairing", run: { e.caret(line: 10, column: 28); e.view?.insertText("(", replacementRange: NSRange(location: NSNotFound, length: 0)) }, check: { e.expect(e.line(10).hasSuffix(";()") && e.caretLine == 10, "line 10: \(e.line(10))") }),
            SelfTestStep(name: "pair backspace", run: { e.view?.deleteBackward(nil) }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");", "line 10: \(e.line(10))") }),
            SelfTestStep(name: "go to line", run: { state.goToLineQuery = "15"; state.confirmGoToLine() }, check: { e.expect(e.caretLine == 15, "caret \(e.caretLine)") }),
            SelfTestStep(name: "back", run: { state.goBack() }, check: { e.expect(e.caretLine == 10, "caret \(e.caretLine)") }),
            SelfTestStep(name: "forward", run: { state.goForward() }, check: { e.expect(e.caretLine == 15, "caret \(e.caretLine)") }),
            SelfTestStep(name: "next method", run: { e.caret(line: 1); state.nextMethod(1) }, check: { e.expect(e.caretLine == 8, "caret \(e.caretLine)") }),
            SelfTestStep(name: "copy reference", run: { state.copyReference() }, check: { e.expect(NSPasteboard.general.string(forType: .string) == "src/main.rs:8", "pasteboard: \(NSPasteboard.general.string(forType: .string) ?? "nil")") }),
            SelfTestStep(name: "find next", run: { state.findQuery = "engine"; state.findOptions = .defaults; state.findOrigin = 0; state.findNext() }, check: { e.expect(e.selectedText == "engine", "selected: \(e.selectedText)") }),
            SelfTestStep(name: "replace all", run: { state.findQuery = "ride"; state.replaceQuery = "RIDE"; state.replaceAll() }, check: { e.expect(e.line(10).contains("RIDE") && e.line(12).contains("RIDE"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "replace back", run: { state.findQuery = "RIDE"; state.replaceQuery = "ride"; state.replaceAll() }, check: { e.expect(e.line(10).contains("\"ride\"") && !e.text.contains("RIDE"), "line 10: \(e.line(10))") }),
            SelfTestStep(name: "format document", wait: 3.0, run: {
                e.view?.replaceText(in: e.lineRange(10), with: "    counter.record(   \"ride\"  );\n")
                state.formatActive()
            }, check: { e.expect(e.line(10) == "    counter.record(\"ride\");" && state.formatError == nil, "line 10: \(e.line(10)) error \(state.formatError ?? "-")") }),
            SelfTestStep(name: "fold", run: { e.caret(line: 9); FoldController.shared.fold() }, check: { e.expect(e.view?.folds.ranges.count == 1, "folds \(e.view?.folds.ranges.count ?? -1)") }),
            SelfTestStep(name: "unfold all", run: { FoldController.shared.unfoldAll() }, check: { e.expect(e.view?.folds.isEmpty == true, "folds remain") }),
            SelfTestStep(name: "gutter fold", run: { FoldController.shared.toggle(line: 8) }, check: {
                e.expect(e.view?.folds.ranges.count == 1 && e.view?.folds.isFoldStart(line: 8) == true, "folds \(e.view?.folds.ranges.count ?? -1) start \(e.view?.folds.isFoldStart(line: 8) ?? false)")
            }),
            SelfTestStep(name: "gutter unfold", run: { FoldController.shared.toggle(line: 8) }, check: { e.expect(e.view?.folds.isEmpty == true, "folds remain") }),
            SelfTestStep(name: "surround", run: { e.caret(line: 10, column: 24); EditorCommands.selectWord(); if let t = EditorCommands.target() { EditorCommand.apply(SurroundWith.apply(SurroundTemplate(title: "(", open: "(", close: ")"), to: t), to: t.view) } }, check: { e.expect(e.line(10).contains("\"(ride)\"") && e.selectedText == "ride", "line 10: \(e.line(10)) sel \(e.selectedText)") }),
            SelfTestStep(name: "zoom", run: { let before = state.prefs.fontSize; state.zoom(1); state.zoomBefore = before }, check: { e.expect(state.prefs.fontSize == state.zoomBefore + 1, "font \(state.prefs.fontSize)") }),
            SelfTestStep(name: "zoom reset", run: { state.resetZoom() }, check: { e.expect(state.prefs.fontSize == Preferences.defaults.fontSize, "font \(state.prefs.fontSize)") }),
            SelfTestStep(name: "recent files", run: {}, check: { e.expect(state.recentFiles.first?.lastPathComponent == "main.rs", "recent \(state.recentFiles)") }),
            SelfTestStep(name: "tree keys", run: {}, check: {
                e.expect(
                    TreeModel.action(keyCode: TreeModel.delete) == .trash
                        && TreeModel.action(keyCode: TreeModel.return) == .rename,
                    "delete \(String(describing: TreeModel.action(keyCode: TreeModel.delete))) return \(String(describing: TreeModel.action(keyCode: TreeModel.return)))"
                )
            }),
            SelfTestStep(name: "save all", run: { state.saveAll() }, check: { e.expect(state.activeBuffer?.isDirty == false, "still dirty") }),
            workspaceOpenSecond(state: state, e: e),
            workspaceRestore(state: state, e: e),
            workspaceSnapshotAfterOpen(state: state, e: e),
            outerSignatureAfterClose(e: e),
            splitHeaderSource(state: state, e: e),
        ]
    }

    private static func workspaceOpenSecond(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "workspace second file", wait: 0.6, run: {
            guard let second = siblingFile(state: state) else {
                return
            }
            state.openFile(second)
            if let main = state.workspaceRoot?.appendingPathComponent("src/main.rs") {
                state.openFile(main)
            }
        }, check: {
            let names = state.buffers.compactMap { $0.fileURL?.lastPathComponent }
            return e.expect(names.count >= 2 && names.contains("main.rs"), "tabs \(names)")
        })
    }

    private static func workspaceRestore(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "workspace restore", wait: 1.0, run: {
            e.caret(line: 10)
            guard let data = try? JSONEncoder().encode(state.captureWorkspace()),
                  let loaded = WorkspaceState.decode(data)
            else {
                return
            }
            state.restoreWorkspace(loaded)
        }, check: {
            let names = state.buffers.compactMap { $0.fileURL?.lastPathComponent }
            return e.expect(
                names.count >= 2 && names.contains("main.rs") && e.caretLine == 10,
                "tabs \(names) caret \(e.caretLine)"
            )
        })
    }

    private static func workspaceSnapshotAfterOpen(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "workspace snapshot after open", wait: 1.0, run: {
            guard let root = state.workspaceRoot else {
                return
            }
            let filled = state.captureWorkspace()
            let empty = WorkspaceState(tabs: [], focusedPath: nil, layout: filled.layout, split: filled.split)
            state.workspaceStore.save(filled, root: root)
            state.workspaceStore.scheduleSave(empty, root: root)
            state.restoreWorkspace(filled)
        }, check: {
            guard let root = state.workspaceRoot else {
                return e.expect(false, "no workspace")
            }
            let tabs = state.workspaceStore.load(root: root)?.tabs ?? []
            return e.expect(!tabs.isEmpty, "tabs \(tabs.map(\.path))")
        })
    }

    private static func outerSignatureAfterClose(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "outer signature after )", wait: 1.0, run: {
            guard let view = e.view else {
                return
            }
            let prefix = "\nfn f(a: i32, b: i32) {}\nfn g(x: i32) {}\nfn _sig() { "
            let start = (view.string as NSString).length
            view.insertText(prefix, replacementRange: NSRange(location: start, length: 0))
            view.setSelectedRange(NSRange(location: start + (prefix as NSString).length, length: 0))
            e.type("f(g(1), ")
        }, check: {
            let name = SignatureHelpController.shared.activeName ?? "nil"
            return e.expect(
                SignatureHelpController.shared.isVisible && SignatureHelpController.shared.activeName == "f",
                "sig \(name) visible \(SignatureHelpController.shared.isVisible)"
            )
        })
    }

    private static func siblingFile(state: AppState) -> URL? {
        guard let current = state.activeBuffer?.fileURL else {
            return nil
        }
        let dir = current.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.sorted().compactMap { name -> URL? in
            if name == current.lastPathComponent || name.hasPrefix(".") {
                return nil
            }
            let url = dir.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
                return nil
            }
            return url
        }.first
    }
}
