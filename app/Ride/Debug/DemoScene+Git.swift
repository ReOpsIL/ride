import AppKit

extension DemoScene {
    static func gitScene(_ name: String, state: AppState) -> Bool {
        guard name == "git" else {
            return false
        }
        state.prefs.outlinePanel = false
        editor(state, file: "src/util.rs", line: 14)
        DemoLaunch.after(1.0) { state.showGit = true }
        ready(when: { gitStaged(state) })
        return true
    }

    private static func gitStaged(_ state: AppState) -> Bool {
        if state.gitChanges.diff != nil {
            return true
        }
        guard state.gitChanges.selection == nil,
              let change = state.git.repo?.changes.first(where: { $0.path.hasSuffix("util.rs") && $0.unstaged != nil })
        else {
            return false
        }
        state.selectGitChange(change, side: .unstaged)
        return false
    }
}
