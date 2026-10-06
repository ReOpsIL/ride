import Foundation

extension AppState {
    func toggleGit() {
        showGit.toggle()
    }

    func showGitCommit() {
        showGit = true
        gitChanges.focusMessage = true
    }

    func refreshGit() {
        guard let root = workspaceRoot else {
            return
        }
        git.refresh(root: root, delay: 0)
    }

    func gitPanelShown() {
        guard showGit else {
            return
        }
        refreshGit()
    }

    func gitStatusChanged() {
        gitChanges.reconcile(with: git.repo)
        syncMenu()
        guard showGit else {
            return
        }
        reloadGitDiff()
        if let root = git.root {
            gitChanges.loadBranches(root: root)
        }
    }

    func selectGitChange(_ change: GitFileChange, side: GitDiffSide) {
        gitChanges.selection = GitSelection(path: change.path, side: side)
        reloadGitDiff()
    }

    func reloadGitDiff() {
        let selection = gitChanges.selection
        let change = gitChanges.change(in: git.repo, for: selection)
        gitChanges.loadDiff(root: git.root ?? "", change: change, side: selection?.side ?? .unstaged)
    }

    func openGitChange(_ change: GitFileChange) {
        guard let url = git.map?.url(change.path), FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        openFile(url)
    }

    func gitAmendChanged() {
        guard gitChanges.amend, gitChanges.message.isEmpty else {
            return
        }
        gitRun("Reading last commit…") { engine, root in
            try engine.gitLastMessage(root: root)
        } done: { [weak self] message in
            guard let self, self.gitChanges.amend, self.gitChanges.message.isEmpty else {
                return
            }
            self.gitChanges.message = message
        }
    }
}
