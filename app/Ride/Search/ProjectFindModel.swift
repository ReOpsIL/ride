import Foundation

final class ProjectFindModel: ObservableObject {
    @Published var query = ""
    @Published var replacement = ""
    @Published var options = FindOptions.defaults
    @Published var matches: [ProjectFindMatch] = []
    @Published var hits: [FileHit] = []
    @Published var included: Set<URL> = []
    @Published var truncated = false
    @Published var running = false
    @Published var selection: Int?
    @Published var showPreview = false
    private var ran = ""
    private var ranOptions = FindOptions.defaults
    private var generation = 0
    var pendingPreview = false

    var needsRun: Bool {
        query != ran || options != ranOptions
    }

    var chosenHits: [FileHit] {
        hits.filter { included.contains($0.file) }
    }

    func run(root: URL?, showHidden: Bool) {
        guard let root else {
            return
        }
        ran = query
        ranOptions = options
        generation += 1
        let gen = generation
        let text = query
        let opts = options
        running = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ProjectFind.search(root: root, query: text, showHidden: showHidden, options: opts)
            DispatchQueue.main.async {
                guard let self, gen == self.generation else {
                    return
                }
                self.take(result)
            }
        }
    }

    func take(_ result: ProjectFindResult) {
        matches = result.matches
        hits = result.hits
        included = Set(result.hits.map(\.file))
        truncated = result.truncated
        selection = result.matches.isEmpty ? nil : 0
        running = false
        if pendingPreview {
            pendingPreview = false
            showPreview = !matches.isEmpty
        }
    }

    func requestPreview() {
        guard !hits.isEmpty else {
            return
        }
        if included.isEmpty {
            included = Set(hits.map(\.file))
        }
        showPreview = true
    }

    func setIncluded(_ file: URL, _ on: Bool) {
        if on {
            included.insert(file)
        } else {
            included.remove(file)
        }
    }

    var selected: ProjectFindMatch? {
        guard let i = selection, matches.indices.contains(i) else {
            return matches.first
        }
        return matches[i]
    }

    func move(_ delta: Int) {
        guard !matches.isEmpty else {
            return
        }
        let current = selection ?? 0
        selection = (current + delta + matches.count) % matches.count
    }

    var groups: [(file: URL, matches: [ProjectFindMatch])] {
        var order: [URL] = []
        var byFile: [URL: [ProjectFindMatch]] = [:]
        for m in matches {
            if byFile[m.file] == nil {
                order.append(m.file)
            }
            byFile[m.file, default: []].append(m)
        }
        return order.map { ($0, byFile[$0] ?? []) }
    }
}
