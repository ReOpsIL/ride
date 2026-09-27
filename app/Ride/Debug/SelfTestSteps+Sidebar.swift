import AppKit

struct SidebarProbe {
    let state: AppState

    var root: URL {
        state.workspaceRoot ?? URL(fileURLWithPath: "/")
    }

    var src: URL { root.appendingPathComponent("src") }
    var probe: URL { src.appendingPathComponent("ride_tree_probe.rs") }
    var renamed: URL { src.appendingPathComponent("ride_tree_renamed.rs") }
    var copy: URL { src.appendingPathComponent("ride_tree_renamed copy.rs") }
    var folder: URL { root.appendingPathComponent("ride_probe_dir") }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func open(_ url: URL) -> Bool {
        state.buffers.contains { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }
    }

    func script(_ answers: Any...) {
        DialogScript.answers = answers
    }

    func pressInTree(_ keys: String, on url: URL) -> Bool {
        state.selectedURL = url
        guard let view = TreeKeyFocus.view, view.window?.makeFirstResponder(view) == true else {
            return false
        }
        return SelfTestKeys.post(keys, window: view.window)
    }
}

extension SelfTestSteps {
    static func sidebarSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let t = SidebarProbe(state: state)
        return [treeNewFile(t: t, e: e), treeCreateExisting(t: t, e: e), treeRename(t: t, e: e), treeDuplicate(t: t, e: e), treeNewFolder(t: t, e: e)]
            + sidebarDeleteSteps(t: t, e: e)
    }

    private static func treeNewFile(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree new file", wait: 0.5, run: {
            t.state.selectedURL = t.src.appendingPathComponent("main.rs")
            t.script(ScriptedName(name: t.probe.lastPathComponent))
            t.state.selectedDirectory.map(t.state.treeNewFile(in:))
        }, check: {
            let active = t.state.activeBuffer?.fileURL?.lastPathComponent
            return e.expect(t.exists(t.probe) && active == t.probe.lastPathComponent && t.state.selectedURL == t.probe && DialogScript.answers.isEmpty,
                            "exists \(t.exists(t.probe)) active \(active ?? "-") selected \(t.state.selectedURL?.lastPathComponent ?? "-")")
        })
    }

    private static func treeCreateExisting(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree create existing name", run: {
            t.state.dismissNotice()
            t.script(ScriptedName(name: t.probe.lastPathComponent))
            t.state.treeNewFile(in: t.src)
        }, check: {
            let notice = t.state.notice ?? ""
            t.state.dismissNotice()
            return e.expect(notice.hasPrefix("Could not create") && notice.contains("already exists"), "notice '\(notice)'")
        })
    }

    private static func treeRename(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree rename", wait: 0.5, run: {
            t.state.toggleBreakpoint(path: t.probe.path, line: 1)
            t.script(ScriptedName(name: t.renamed.lastPathComponent))
            t.state.runTreeAction(.rename, url: t.probe)
        }, check: {
            let moved = t.state.debug.breakpoints.lines(path: t.renamed.standardizedFileURL.path).contains(1)
            let stale = !t.state.debug.breakpoints.lines(path: t.probe.standardizedFileURL.path).isEmpty
            return e.expect(t.exists(t.renamed) && !t.exists(t.probe) && t.open(t.renamed) && !t.open(t.probe) && t.state.selectedURL == t.renamed && moved && !stale,
                            "renamed \(t.exists(t.renamed)) open \(t.open(t.renamed)) selected \(t.state.selectedURL?.lastPathComponent ?? "-") breakpoint moved \(moved) stale \(stale)")
        })
    }

    private static func treeDuplicate(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree duplicate", wait: 0.5, run: { t.state.treeDuplicate(t.renamed) }, check: {
            e.expect(t.exists(t.copy) && t.state.selectedURL == t.copy, "copy \(t.exists(t.copy)) selected \(t.state.selectedURL?.lastPathComponent ?? "-")")
        })
    }

    private static func treeNewFolder(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree new folder", wait: 0.5, run: {
            t.script(ScriptedName(name: t.folder.lastPathComponent), ScriptedName(name: t.folder.lastPathComponent))
            t.state.treeNewFolder(in: t.root)
            t.state.dismissNotice()
            t.state.treeNewFolder(in: t.root)
        }, check: {
            let notice = t.state.notice ?? ""
            t.state.dismissNotice()
            let listed = t.state.rootNodes.contains { $0.url.standardizedFileURL == t.folder.standardizedFileURL }
            return e.expect(t.exists(t.folder) && listed && notice.contains("already exists"), "folder \(t.exists(t.folder)) listed \(listed) notice '\(notice)'")
        })
    }
}
