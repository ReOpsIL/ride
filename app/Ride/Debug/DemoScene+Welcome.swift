import AppKit

extension DemoScene {
    static func welcome(_ name: String, state: AppState) -> Bool {
        guard name == "welcome" else {
            return false
        }
        state.prefs.outlinePanel = false
        ToolsModel.shared.refresh()
        ready(when: { welcomeStaged(state) }, timeout: 60)
        return true
    }

    private static func welcomeStaged(_ state: AppState) -> Bool {
        state.workspaceRoot == nil && !ToolsModel.shared.rows.isEmpty
    }
}
