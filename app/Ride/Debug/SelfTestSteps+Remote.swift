import AppKit

extension SelfTestSteps {
    static func remoteMenuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "menu remote toolchain", wait: 0.4, run: {
                _ = SelfTestMenu.perform("Run › Remote Toolchain…")
            }, check: {
                e.expect(state.showRemoteSheet, "shown \(state.showRemoteSheet)")
            }),
            SelfTestStep(name: "remote toolchain test explains identity", wait: 0.3, run: {
                let editor = state.remoteEditor
                editor.draft.kind = .docker
                editor.draft.user = "dev"
                editor.draft.name = "ride-rust"
                editor.draft.identity = "169c7e84f07c"
                editor.draft.remoteRoot = "/work/demo"
                state.testRemote()
            }, check: {
                guard case let .rejected(message) = state.remoteEditor.probe else {
                    return e.expect(false, "probe \(state.remoteEditor.probe)")
                }
                return e.expect(message.contains("absolute path of an SSH private key"), message)
            }),
            SelfTestStep(name: "remote toolchain save", wait: 0.3, run: {
                let editor = state.remoteEditor
                editor.draft.enabled = true
                editor.draft.kind = .vm
                editor.draft.user = "dev"
                editor.draft.host = "builder"
                editor.draft.remoteRoot = "/src/ride"
                state.saveRemote()
                state.remoteToolchain.enabled = false
            }, check: {
                let saved = state.remoteToolchain
                return e.expect(
                    !state.showRemoteSheet && saved.host == "builder" && saved.remoteRoot == "/src/ride" && !saved.enabled,
                    "shown \(state.showRemoteSheet) host \(saved.host) enabled \(saved.enabled)"
                )
            }),
        ]
    }
}
