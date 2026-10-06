import Foundation

struct GitSelection: Equatable {
    let path: String
    let side: GitDiffSide
}

final class GitChangesModel: ObservableObject {
    @Published var selection: GitSelection?
    @Published private(set) var diff: GitFileDiff?
    @Published private(set) var diffRows: [GitDiffRow] = []
    @Published private(set) var diffError: String?
    @Published var message = ""
    @Published var amend = false
    @Published var busy: String?
    @Published private(set) var branches: [GitBranch] = []
    @Published var focusMessage = false
    private var diffGeneration = 0
    private var branchGeneration = 0

    var isBusy: Bool {
        busy != nil
    }

    func change(in repo: GitRepoStatus?, for selection: GitSelection?) -> GitFileChange? {
        guard let selection else {
            return nil
        }
        return repo?.changes.first { $0.path == selection.path && $0.kind(on: selection.side) != nil }
    }

    func reconcile(with repo: GitRepoStatus?) {
        guard let current = selection, change(in: repo, for: current) == nil else {
            return
        }
        let other = GitSelection(path: current.path, side: current.side == .staged ? .unstaged : .staged)
        selection = change(in: repo, for: other) == nil ? nil : other
    }

    func loadDiff(root: String, change: GitFileChange?, side: GitDiffSide) {
        diffGeneration += 1
        let gen = diffGeneration
        guard let change else {
            show(nil, error: nil)
            return
        }
        RideEngineClient.shared.withEngine { engine in
            Result { try engine.gitDiff(root: root, change: change, side: side) }
        } then: { [weak self] result in
            guard let self, gen == self.diffGeneration else {
                return
            }
            switch result {
            case .success(let diff):
                self.show(diff, error: nil)
            case .failure(let error):
                self.show(nil, error: GitErrorText.message(error))
            }
        }
    }

    private func show(_ diff: GitFileDiff?, error: String?) {
        if self.diff != diff {
            self.diff = diff
            diffRows = diff.map(GitDiffRow.rows) ?? []
        }
        diffError = error
    }

    func loadBranches(root: String) {
        branchGeneration += 1
        let gen = branchGeneration
        RideEngineClient.shared.withEngine(qos: .utility) { engine in
            (try? engine.gitBranches(root: root)) ?? []
        } then: { [weak self] branches in
            guard let self, gen == self.branchGeneration, self.branches != branches else {
                return
            }
            self.branches = branches
        }
    }

    func reset() {
        diffGeneration += 1
        branchGeneration += 1
        selection = nil
        show(nil, error: nil)
        branches = []
        busy = nil
        amend = false
    }
}
