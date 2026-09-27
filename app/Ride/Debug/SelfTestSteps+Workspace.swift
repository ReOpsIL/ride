import AppKit

extension SelfTestSteps {
    static func workspaceOpenSecond(state: AppState, e: SelfTestEditor, file: SelfTestOpened, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "open second file", wait: 0.6, run: {
                scratch.saved = e.text
                guard let second = siblingFile(state: state) else {
                    return
                }
                state.openFile(second)
                _ = state.captureWorkspace()
            }, check: {
                let second = state.activeBuffer?.fileURL
                let disk = second.flatMap { BufferDocument.load($0)?.text } ?? ""
                return e.expect(
                    second?.lastPathComponent != file.fileName && !disk.isEmpty && e.text == disk,
                    "active \(second?.lastPathComponent ?? "nil") view \(e.text.prefix(60))"
                )
            }),
            SelfTestStep(name: "reopen first file", wait: 0.6, run: {
                if let current = state.workspaceRoot?.appendingPathComponent(file.filePath) {
                    state.openFile(current)
                }
            }, check: {
                let names = state.buffers.compactMap { $0.fileURL?.lastPathComponent }
                return e.expect(
                    names.count >= 2 && state.activeBuffer?.fileURL?.lastPathComponent == file.fileName && e.text == scratch.saved,
                    "tabs \(names) active \(state.activeBuffer?.displayName ?? "nil") view \(e.text.prefix(60))"
                )
            }),
            SelfTestStep(name: "dirty survives tab switch", wait: 0.6, run: {
                let end = (e.text as NSString).length
                e.view?.insertText("\n", replacementRange: NSRange(location: end, length: 0))
                if let second = siblingFile(state: state) {
                    state.openFile(second)
                }
                if let current = state.workspaceRoot?.appendingPathComponent(file.filePath) {
                    state.openFile(current)
                }
            }, check: {
                let dirty = state.activeBuffer?.isDirty == true
                let undone: Bool = {
                    e.undo()
                    return e.text == scratch.saved
                }()
                return e.expect(dirty && undone, "dirty \(dirty) text \(e.text.suffix(20))")
            }),
        ]
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
            state.workspaceStore.scheduleSave(root: root) { empty }
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
            return WorkspaceFS.isFile(url) ? url : nil
        }.first
    }
}
