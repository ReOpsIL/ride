import AppKit

extension SelfTestSteps {
    static func sampleSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let original = state.workspaceRoot
        let destination = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ride-sample-\(UUID().uuidString)", isDirectory: true)
        return [
            SelfTestStep(name: "sample project copied", wait: 2.0, run: {
                guard let sample = SampleProjects.sample(id: "rust-demo") else {
                    return
                }
                state.openSample(sample, at: destination)
            }, check: {
                let manifest = WorkspaceFS.isFile(destination.appendingPathComponent("Cargo.toml"))
                let main = WorkspaceFS.isFile(destination.appendingPathComponent("src/main.rs"))
                return e.expect(
                    manifest && main && rooted(state, at: destination),
                    "manifest \(manifest) main \(main) root \(state.workspaceRoot?.path ?? "nil")"
                )
            }),
            SelfTestStep(name: "sample project reopen", wait: 2.0, run: {
                if let original {
                    state.open(original)
                }
                try? FileManager.default.removeItem(at: destination)
            }, check: {
                guard let original else {
                    return e.expect(false, "no original workspace")
                }
                return e.expect(
                    rooted(state, at: original),
                    "root \(state.workspaceRoot?.path ?? "nil")"
                )
            }),
        ]
    }

    private static func rooted(_ state: AppState, at url: URL) -> Bool {
        state.workspaceRoot?.resolvingSymlinksInPath().path == url.resolvingSymlinksInPath().path
    }
}
