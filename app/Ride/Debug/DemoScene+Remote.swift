import AppKit

extension DemoScene {
    static func remoteScene(_ name: String, state: AppState) -> Bool {
        guard name == "remote" else {
            return false
        }
        editor(state)
        DemoLaunch.after(1.4) {
            state.editRemote()
            let editor = state.remoteEditor
            editor.draft.enabled = true
            editor.draft.kind = .docker
            editor.draft.user = "dev"
            editor.draft.name = "ride-rust"
            editor.draft.identity = "~/.ssh/ride_docker"
            editor.draft.remoteRoot = "/work/rust-demo"
            state.testRemote()
        }
        ready(when: { probed(state.remoteEditor.probe) })
        return true
    }

    private static func probed(_ probe: RemoteProbeState) -> Bool {
        switch probe {
        case .finished, .rejected:
            true
        case .idle, .running:
            false
        }
    }
}
