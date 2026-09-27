import AppKit

extension SelfTestSteps {
    static func menusFile(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let e = c.e
        let notes = c.url("menu-notes.md")
        let notes2 = c.url("menu-notes-2.md")
        let dirty = { state.activeBuffer?.isDirty ?? true }
        let append = { (text: String) in
            let end = (e.text as NSString).length
            e.view?.insertText(text, replacementRange: NSRange(location: end, length: 0))
        }
        return [
            c.step("menu new file", "File › New File…", prepare: {
                [notes, notes2].compactMap { $0 }.forEach { try? FileManager.default.removeItem(at: $0) }
                c.script(notes.map { ScriptedURL(url: $0) })
            }) {
                let exists = notes.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                return (c.activeName == "menu-notes.md" && exists && DialogScript.pending == 0, "active \(c.activeName) exists \(exists)")
            },
            c.step("menu save", "File › Save", prepare: {
                e.view?.insertText("# Menu notes\n\nalpha beta\n", replacementRange: NSRange(location: 0, length: (e.text as NSString).length))
            }) {
                (c.disk(notes) == e.text && e.text.hasPrefix("# Menu notes") && !dirty(), "disk '\(c.disk(notes))' dirty \(dirty())")
            },
            c.step("menu revert cancel", "File › Revert to Saved", prepare: {
                append("junk\n")
                c.script(false)
            }) {
                (e.text.hasSuffix("junk\n") && dirty() && DialogScript.pending == 0, "text '\(e.text)'")
            },
            c.step("menu revert", "File › Revert to Saved") {
                (e.text == c.disk(notes) && !dirty(), "text '\(e.text)' dirty \(dirty())")
            },
            c.step("menu save all", "File › Save All", prepare: { append("gamma\n") }) {
                (c.disk(notes).hasSuffix("gamma\n") && !dirty(), "disk '\(c.disk(notes))'")
            },
            c.step("menu markdown preview", "View › Toggle Markdown Preview", wait: 0.5, until: { !state.preview.html.isEmpty }, timeout: 5) {
                (state.previewVisible && state.preview.html.contains("Menu notes"), "visible \(state.previewVisible) html \(state.preview.html.count)")
            },
            c.step("menu markdown preview close", "View › Toggle Markdown Preview") {
                (!state.showPreview, "shown \(state.showPreview)")
            },
            c.step("menu save as", "File › Save As…", prepare: {
                c.script(notes2.map { ScriptedURL(url: $0) })
            }) {
                (c.activeName == "menu-notes-2.md" && c.disk(notes2) == e.text && !dirty(), "active \(c.activeName) disk '\(c.disk(notes2))'")
            },
            c.step("menu new buffer", "File › New Buffer", prepare: { c.number = state.buffers.count }) {
                let revert = SelfTestMenu.isEnabled("File › Revert to Saved")
                return (state.buffers.count == c.number + 1 && state.activeBuffer?.fileURL == nil && !revert, "buffers \(state.buffers.count) revert enabled \(revert)")
            },
            c.step("menu close editor", "File › Close Editor") {
                (state.buffers.count == c.number && state.activeBuffer?.fileURL != nil, "buffers \(state.buffers.count) active \(c.activeName)")
            },
            c.openStep("menu notes reopen", notes2),
            c.step("menu close editor saves", "File › Close Editor", prepare: {
                append("delta\n")
                c.script(CloseChoice.save)
            }) {
                let open = state.buffers.contains { $0.fileURL == notes2 }
                return (!open && c.disk(notes2).hasSuffix("delta\n") && DialogScript.pending == 0, "open \(open) disk '\(c.disk(notes2))'")
            },
            c.step("menu open", "File › Open…", prepare: {
                c.script(notes2.map { ScriptedURL(url: $0) })
            }) {
                (c.activeName == "menu-notes-2.md" && DialogScript.pending == 0, "active \(c.activeName)")
            },
        ] + menusFileProject(c)
    }

    private static func menusFileProject(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let folder = c.url("menu-folder")
        let exists = { folder.map { WorkspaceFS.isDirectory($0) } ?? false }
        let sheet = { MainWindow.window?.attachedSheet }
        return [
            c.step("menu new folder", "File › New Folder…", prepare: {
                folder.map { try? FileManager.default.removeItem(at: $0) }
                state.selectedURL = nil
                c.script(ScriptedName(name: "menu-folder"))
            }) {
                (exists() && DialogScript.pending == 0, "folder \(exists()) selected \(state.selectedURL?.path ?? "nil")")
            },
            c.step("menu new folder exists", "File › New Folder…", prepare: {
                state.selectedURL = nil
                c.script(ScriptedName(name: "menu-folder"))
            }) {
                let notice = state.notice ?? "nil"
                folder.map { try? FileManager.default.removeItem(at: $0) }
                return (notice.hasPrefix("Could not create menu-folder") && DialogScript.pending == 0, "notice \(notice)")
            },
            c.step("menu reindex", "File › Reindex") {
                let notice = state.notice ?? "nil"
                let helper = IndexerProcess.helperURL().map { FileManager.default.isExecutableFile(atPath: $0.path) } ?? false
                let expected = helper ? ["Reindexing", "Reindexed"] : ["Could not start the indexer"]
                return (expected.contains { notice.hasPrefix($0) }, "notice \(notice) helper \(helper)")
            },
            c.step("menu new project", "File › New Project…", until: { sheet() != nil }, timeout: 3) {
                (state.showNewProjectSheet && sheet() != nil, "flag \(state.showNewProjectSheet) sheet \(sheet() != nil)")
            },
            SelfTestStep(name: "menu new project cancel", until: { sheet() == nil }, timeout: 3, run: {
                state.showNewProjectSheet = false
            }, check: { c.e.expect(sheet() == nil && !state.showNewProjectSheet, "sheet still open") }),
        ]
    }
}
