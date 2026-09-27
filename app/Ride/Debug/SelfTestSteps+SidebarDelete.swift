import AppKit

extension SelfTestSteps {
    static func sidebarDeleteSteps(t: SidebarProbe, e: SelfTestEditor) -> [SelfTestStep] {
        [treeDeleteCancelled(t: t, e: e), treeOptionReturnIgnored(t: t, e: e), treeDeleteOpenFile(t: t, e: e), treeDeleteRest(t: t, e: e), treeCopyPaths(t: t, e: e)]
    }

    private static func treeDeleteCancelled(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree delete cancelled", wait: 0.6, run: {
            t.script(false)
            _ = t.pressInTree("⌘⌫", on: t.copy)
        }, check: {
            e.expect(t.exists(t.copy) && DialogScript.answers.isEmpty, "exists \(t.exists(t.copy)) unanswered \(DialogScript.answers.count)")
        })
    }

    private static func treeOptionReturnIgnored(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree option return ignored", wait: 0.6, run: {
            t.script(ScriptedName(name: "ride_should_not_rename.rs"))
            _ = t.pressInTree("⌥↩", on: t.copy)
        }, check: {
            let untouched = DialogScript.answers.count == 1 && t.exists(t.copy)
            DialogScript.answers = []
            return e.expect(untouched, "the tree acted on ⌥↩")
        })
    }

    private static func treeDeleteOpenFile(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree delete open file", until: { !t.exists(t.renamed) && !t.open(t.renamed) }, timeout: 5, run: {
            t.script(true)
            _ = t.pressInTree("⌘⌫", on: t.renamed)
        }, check: {
            let breakpoints = t.state.debug.breakpoints.lines(path: t.renamed.standardizedFileURL.path)
            return e.expect(!t.exists(t.renamed) && !t.open(t.renamed) && breakpoints.isEmpty && t.state.selectedURL != t.renamed,
                            "exists \(t.exists(t.renamed)) open \(t.open(t.renamed)) breakpoints \(breakpoints)")
        })
    }

    private static func treeDeleteRest(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree delete key", until: { !t.exists(t.copy) && !t.exists(t.folder) }, timeout: 5, run: {
            t.script(true, true)
            _ = t.pressInTree("⌫", on: t.copy)
            t.state.runTreeAction(.trash, url: t.folder)
        }, check: {
            e.state.openFile(t.src.appendingPathComponent("main.rs"))
            e.focus()
            return e.expect(!t.exists(t.copy) && !t.exists(t.folder), "copy \(t.exists(t.copy)) folder \(t.exists(t.folder))")
        })
    }

    private static func treeCopyPaths(t: SidebarProbe, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "tree copy paths", run: {}, check: {
            let file = t.src.appendingPathComponent("main.rs")
            let relative = TreeActions.pathText(file, root: t.root)
            let absolute = TreeActions.pathText(file, root: nil)
            return e.expect(relative == "src/main.rs" && absolute == file.path, "relative \(relative) absolute \(absolute)")
        })
    }
}
