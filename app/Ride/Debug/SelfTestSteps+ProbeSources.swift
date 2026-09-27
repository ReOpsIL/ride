import AppKit

final class ProbeSources {
    static let files = ["src/main.rs", "src/util.rs"]
    var saved: [String: String] = [:]
}

extension SelfTestSteps {
    static func pristineSources(state: AppState, e: SelfTestEditor, sources: ProbeSources) -> SelfTestStep {
        SelfTestStep(name: "pristine sample sources", until: { e.text.contains("counter.record(\"ride\");") }, timeout: 6, run: {
            state.updatePrefs { $0.autoSave = true }
            for relative in ProbeSources.files {
                let url = workspaceFile(state, relative)
                sources.saved[relative] = try? String(contentsOf: url, encoding: .utf8)
                if let pristine = SampleProjects.directory.flatMap({ try? String(contentsOf: $0.appendingPathComponent("rust-demo/\(relative)"), encoding: .utf8) }) {
                    write(pristine, to: url, state: state)
                }
            }
            state.openFile(workspaceFile(state, "src/main.rs"))
        }, check: { e.expect(e.text.contains("counter.record(\"ride\");"), "main.rs is not the sample") })
    }

    static func restoreSources(state: AppState, e: SelfTestEditor, sources: ProbeSources) -> SelfTestStep {
        SelfTestStep(name: "restore sample sources", wait: 0.6, run: {
            for (relative, text) in sources.saved {
                write(text, to: workspaceFile(state, relative), state: state)
            }
        }, check: {
            let same = sources.saved.allSatisfy { (try? String(contentsOf: workspaceFile(state, $0.key), encoding: .utf8)) == $0.value }
            return e.expect(same, "sources not restored")
        })
    }

    private static func workspaceFile(_ state: AppState, _ relative: String) -> URL {
        (state.workspaceRoot ?? URL(fileURLWithPath: "/")).appendingPathComponent(relative)
    }

    private static func write(_ text: String, to url: URL, state: AppState) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
        if let buffer = state.buffers.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
            state.reloadFromDisk(buffer)
        }
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
    }
}
