import AppKit

enum SelfTestSteps {
    static let blockOpen = "/" + "*"
    static let blockClose = "*" + "/"

    static func all(state: AppState) -> [SelfTestStep] {
        let e = SelfTestEditor(state: state)
        let file = SelfTestOpened.from(state)
        let scratch = SelfTestScratch()
        switch state.activeBuffer?.language ?? .rust {
        case .c, .cpp:
            return cpp(state: state, e: e, file: file, scratch: scratch)
        default:
            return rust(state: state, e: e, file: file, scratch: scratch)
        }
    }

    static func setup(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "setup", wait: 1.5, run: {
            e.focus()
            scratch.body = e.line(file.bodyLine)
            scratch.next = e.line(file.bodyLine + 1)
        }, check: { e.expect(e.view != nil && e.lines.count > 15 && !scratch.body.isEmpty, "editor missing") })
    }

    static func indentKeeps(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "indent keeps selection", run: {
            e.selectLines(file.bodyLine, file.bodyLine)
            e.view?.insertTab(nil)
        }, check: {
            e.expect(
                e.line(file.bodyLine) == "    " + scratch.body && (e.view?.selectedRange().length ?? 0) > 0,
                "line \(file.bodyLine): \(e.line(file.bodyLine)) sel \(String(describing: e.view?.selectedRange()))"
            )
        })
    }

    static func unindentKeeps(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "unindent keeps selection", run: { e.view?.insertBacktab(nil) }, check: {
            e.expect(
                e.line(file.bodyLine) == scratch.body && (e.view?.selectedRange().length ?? 0) > 0,
                "line \(file.bodyLine): \(e.line(file.bodyLine))"
            )
        })
    }

    static func tabInserts(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "tab inserts spaces", run: { e.caret(line: file.bodyLine, column: 5); e.view?.insertTab(nil) }, check: {
            e.expect(e.line(file.bodyLine) == "    " + scratch.body, "line \(file.bodyLine): \(e.line(file.bodyLine))")
        })
    }

    static func undoOneStep(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "undo is one step", run: { e.view?.undoManager?.undo() }, check: {
            e.expect(e.line(file.bodyLine) == scratch.body, "line \(file.bodyLine): \(e.line(file.bodyLine))")
        })
    }

    static func duplicateLine(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "duplicate line", run: { e.caret(line: file.bodyLine); EditorCommands.duplicate() }, check: {
            e.expect(e.line(file.bodyLine + 1) == e.line(file.bodyLine) && e.line(file.bodyLine) == scratch.body, "line \(file.bodyLine + 1): \(e.line(file.bodyLine + 1))")
        })
    }

    static func deleteLine(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "delete line", run: { EditorCommands.deleteLines() }, check: {
            e.expect(e.line(file.bodyLine + 1) == scratch.next, "line \(file.bodyLine + 1): \(e.line(file.bodyLine + 1))")
        })
    }

    static func moveLineDown(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "move line down", run: { e.caret(line: file.bodyLine); EditorCommands.moveLines(up: false) }, check: {
            e.expect(e.line(file.bodyLine) == scratch.next && e.line(file.bodyLine + 1) == scratch.body, "\(e.line(file.bodyLine)) | \(e.line(file.bodyLine + 1))")
        })
    }

    static func moveLineUp(e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> SelfTestStep {
        SelfTestStep(name: "move line up", run: { EditorCommands.moveLines(up: true) }, check: {
            e.expect(e.line(file.bodyLine) == scratch.body && e.caretLine == file.bodyLine, "\(e.line(file.bodyLine)) caret \(e.caretLine)")
        })
    }

    static func goToLine(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "go to line", run: {
            e.caret(line: file.bodyLine)
            state.goToLineQuery = "\(file.goToLine)"
            state.confirmGoToLine()
        }, check: { e.expect(e.caretLine == file.goToLine, "caret \(e.caretLine)") })
    }

    static func back(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "back", run: { state.goBack() }, check: { e.expect(e.caretLine == file.bodyLine, "caret \(e.caretLine)") })
    }

    static func forward(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "forward", run: { state.goForward() }, check: { e.expect(e.caretLine == file.goToLine, "caret \(e.caretLine)") })
    }

    static func zoomIn(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "zoom", run: { let before = state.prefs.fontSize; state.zoom(1); state.zoomBefore = before }, check: {
            e.expect(state.prefs.fontSize == state.zoomBefore + 1, "font \(state.prefs.fontSize)")
        })
    }

    static func zoomReset(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "zoom reset", run: { state.resetZoom() }, check: {
            e.expect(state.prefs.fontSize == Preferences.defaults.fontSize, "font \(state.prefs.fontSize)")
        })
    }

    static func workspaceOpenSecond(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "workspace second file", wait: 0.6, run: {
            guard let second = siblingFile(state: state) else {
                return
            }
            state.openFile(second)
            if let current = state.workspaceRoot?.appendingPathComponent(file.filePath) {
                state.openFile(current)
            }
        }, check: {
            let names = state.buffers.compactMap { $0.fileURL?.lastPathComponent }
            return e.expect(names.count >= 2 && names.contains(file.fileName), "tabs \(names)")
        })
    }

    static func workspaceRestore(state: AppState, e: SelfTestEditor, file: SelfTestOpened) -> SelfTestStep {
        SelfTestStep(name: "workspace restore", wait: 1.0, run: {
            e.caret(line: file.bodyLine)
            guard let data = try? JSONEncoder().encode(state.captureWorkspace()),
                  let loaded = WorkspaceState.decode(data)
            else {
                return
            }
            state.restoreWorkspace(loaded)
        }, check: {
            let names = state.buffers.compactMap { $0.fileURL?.lastPathComponent }
            return e.expect(
                names.count >= 2 && names.contains(file.fileName) && e.caretLine == file.bodyLine,
                "tabs \(names) caret \(e.caretLine)"
            )
        })
    }

    static func workspaceSnapshotAfterOpen(state: AppState, e: SelfTestEditor) -> SelfTestStep {
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

    static func siblingFile(state: AppState) -> URL? {
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
