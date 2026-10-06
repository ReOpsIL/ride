import Foundation

extension AppState {
    func gitRun<T>(
        _ title: String,
        _ op: @escaping (Engine, String) throws -> T,
        done: @escaping (T) -> Void = { _ in }
    ) {
        guard let root = git.root, !gitChanges.isBusy else {
            return
        }
        saveAll()
        gitChanges.busy = title
        RideEngineClient.shared.withEngine { engine in
            Result { try op(engine, root) }
        } then: { [weak self] result in
            guard let self else {
                return
            }
            self.gitChanges.busy = nil
            self.refreshGit()
            switch result {
            case .success(let value):
                done(value)
            case .failure(let error):
                self.showNotice(GitErrorText.message(error), seconds: 10)
            }
        }
    }

    func gitStage(_ paths: [String]) {
        guard !paths.isEmpty else {
            return
        }
        gitRun("Staging…") { try $0.gitStage(root: $1, paths: paths) }
    }

    func gitUnstage(_ paths: [String]) {
        guard !paths.isEmpty else {
            return
        }
        gitRun("Unstaging…") { try $0.gitUnstage(root: $1, paths: paths) }
    }

    func gitDiscard(_ changes: [GitFileChange]) {
        let unstaged = changes.filter { $0.unstaged != nil }
        guard !unstaged.isEmpty else {
            return
        }
        let what = unstaged.count == 1 ? unstaged[0].name : Plural.count(unstaged.count, "file")
        let deletes = unstaged.contains { $0.unstaged == .untracked }
        let detail = deletes ? "Untracked files are deleted. This cannot be undone." : "This cannot be undone."
        guard Confirm.ask("Discard changes to \(what)?", message: detail, ok: "Discard") else {
            return
        }
        gitRun("Discarding…") { try $0.gitDiscard(root: $1, changes: unstaged) }
    }

    func gitCommit(push: Bool) {
        let message = gitChanges.message
        let amend = gitChanges.amend
        let stageAll = !amend && !(git.repo?.changes.contains { $0.staged != nil } ?? false)
        gitRun("Committing…") { (engine: Engine, root: String) throws -> String in
            if stageAll {
                try engine.gitStage(root: root, paths: ["."])
            }
            return try engine.gitCommit(root: root, message: message, amend: amend)
        } done: { [weak self] summary in
            guard let self else {
                return
            }
            self.gitChanges.message = ""
            self.gitChanges.amend = false
            self.showNotice(GitErrorText.summary(summary, fallback: "Committed"))
            if push {
                self.gitPush()
            }
        }
    }

    func gitPush() {
        gitRun("Pushing…") { try $0.gitPush(root: $1) } done: { [weak self] out in
            self?.showNotice(GitErrorText.summary(out, fallback: "Pushed"))
        }
    }

    func gitPull() {
        gitRun("Pulling…") { try $0.gitPull(root: $1) } done: { [weak self] out in
            self?.showNotice(GitErrorText.summary(out, fallback: "Pulled"))
        }
    }

    func gitFetch() {
        gitRun("Fetching…") { try $0.gitFetch(root: $1) } done: { [weak self] out in
            self?.showNotice(GitErrorText.summary(out, fallback: "Fetched"))
        }
    }

    func gitNewBranch() {
        guard git.root != nil, let name = TreePrompt.name(title: "New Branch", defaultName: "") else {
            return
        }
        gitRun("Creating branch…") { try $0.gitCreateBranch(root: $1, name: name, checkout: true) } done: { [weak self] _ in
            self?.showNotice("Switched to new branch \(name)")
        }
    }

    func gitCheckout(_ branch: GitBranch) {
        gitRun("Switching branch…") { try $0.gitCheckout(root: $1, branch: branch) } done: { [weak self] _ in
            self?.showNotice("Switched to \(branch.name)")
        }
    }
}
