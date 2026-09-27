import AppKit

extension SelfTestSteps {
    static func menusWorkspace(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let engine = RideEngineClient.shared
        let scratch = ["src/menu_probe.rs", "menu-notes.md", "menu-notes-2.md", "menu-folder"].compactMap { c.url($0) }
        let recent = "File › Open Recent › \(c.root?.lastPathComponent ?? "demo")"
        let rooted = { state.workspaceRoot?.resolvingSymlinksInPath() == c.root?.resolvingSymlinksInPath() }
        return [
            c.step("menu close others", "File › Close Others", prepare: {
                c.url("menu-notes-2.md").map { state.openFile($0) }
            }) {
                (state.buffers.count == 1 && c.activeName == "menu-notes-2.md", "buffers \(state.buffers.map(\.displayName))")
            },
            c.step("menu close all", "File › Close All") {
                (state.buffers.isEmpty, "buffers \(state.buffers.map(\.displayName))")
            },
            SelfTestStep(name: "menu scratch cleanup", run: {
                DialogScript.clear()
                scratch.forEach { try? FileManager.default.removeItem(at: $0) }
            }, check: {
                let left = scratch.filter { FileManager.default.fileExists(atPath: $0.path) }
                let open = left.filter { url in c.state.buffers.contains { $0.fileURL?.standardizedFileURL == url.standardizedFileURL } }
                return c.e.expect(left.isEmpty, "scratch files remain \(left.map(\.lastPathComponent)) open \(open.map(\.lastPathComponent))")
            }),
            c.step("menu close workspace", "File › Close Workspace", wait: 0.5) {
                (
                    state.workspaceRoot == nil && !state.watcher.isWatching && engine.openRoot == nil && state.rootNodes.isEmpty,
                    "root \(state.workspaceRoot?.path ?? "nil") watching \(state.watcher.isWatching) engine \(engine.openRoot?.path ?? "nil")"
                )
            },
            c.step("menu open recent", recent, wait: 1.0) {
                (
                    rooted() && state.watcher.isWatching && engine.openRoot != nil,
                    "root \(state.workspaceRoot?.path ?? "nil") watching \(state.watcher.isWatching) engine \(engine.openRoot?.path ?? "nil")"
                )
            },
            SelfTestStep(name: "menu open recent pruned", run: {}, check: {
                _ = SelfTestMenu.isEnabled(recent)
                let titles = SelfTestMenu.item("File › Open Recent")?.submenu?.items.map(\.title) ?? []
                let missing = state.recent.filter { !FileManager.default.fileExists(atPath: $0.path) }
                return c.e.expect(missing.isEmpty && titles.count == state.recent.count, "titles \(titles) missing \(missing)")
            }),
            c.openStep("menu main reopen", c.url("src/main.rs")),
        ]
    }
}
