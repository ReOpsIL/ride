import Foundation

extension AppState {
    func projectFindSubmit() {
        if projectFind.needsRun || projectFind.matches.isEmpty {
            projectFind.run(root: workspaceRoot, showHidden: prefs.showHidden)
            return
        }
        if let match = projectFind.selected {
            openProjectMatch(match)
        }
    }

    func projectFindPreview() {
        if projectFind.needsRun || projectFind.matches.isEmpty {
            projectFind.pendingPreview = true
            projectFind.run(root: workspaceRoot, showHidden: prefs.showHidden)
            return
        }
        projectFind.requestPreview()
    }

    func openProjectMatch(_ match: ProjectFindMatch) {
        showProjectFind = false
        openFile(match.file, at: .byte(match.byte))
    }
}
