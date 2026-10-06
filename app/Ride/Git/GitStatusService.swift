import Foundation

final class GitStatusService: ObservableObject {
    @Published private(set) var repo: GitRepoStatus?
    @Published private(set) var marks = GitTreeMarks.empty
    private(set) var map: GitPathMap?
    var onChange: (() -> Void)?
    private var work: DispatchWorkItem?
    private var generation = 0

    var branch: String? {
        guard let repo else {
            return nil
        }
        return repo.branch ?? repo.head.map { "detached at \($0)" } ?? "no commits"
    }

    var root: String? {
        repo?.root
    }

    func refresh(root: URL, delay: TimeInterval = 1) {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.run(workspace: root)
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func clear() {
        work?.cancel()
        generation += 1
        repo = nil
        map = nil
        marks = .empty
        onChange?()
    }

    func kind(relative: String) -> GitChangeKind? {
        marks.kind(relative: relative)
    }

    func containsChange(directory relative: String) -> Bool {
        marks.containsChange(directory: relative)
    }

    private func run(workspace: URL) {
        generation += 1
        let gen = generation
        RideEngineClient.shared.withEngine(qos: .utility) { engine in
            try? engine.gitStatus(root: workspace.path)
        } then: { [weak self] status in
            guard let self, gen == self.generation else {
                return
            }
            self.apply(status, workspace: workspace)
        }
    }

    private func apply(_ status: GitRepoStatus?, workspace: URL) {
        let map = status.map { GitPathMap(repoRoot: $0.root, workspace: workspace) }
        if repo != status {
            repo = status
        }
        self.map = map
        let marks = Self.marks(status, map)
        if self.marks != marks {
            self.marks = marks
        }
        onChange?()
    }

    private static func marks(_ status: GitRepoStatus?, _ map: GitPathMap?) -> GitTreeMarks {
        guard let status, let map else {
            return .empty
        }
        return GitTreeMarks(status: status, map: map)
    }
}
