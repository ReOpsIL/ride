import Foundation

final class ProjectFindModel: ObservableObject {
    @Published var query = ""
    @Published var matches: [ProjectFindMatch] = []
    @Published var truncated = false
    @Published var running = false
    @Published var selection: Int?
    private var ran = ""
    private var generation = 0

    var needsRun: Bool {
        query != ran
    }

    func run(root: URL?, showHidden: Bool) {
        guard let root else {
            return
        }
        ran = query
        generation += 1
        let gen = generation
        let text = query
        running = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ProjectFind.search(root: root, query: text, showHidden: showHidden)
            DispatchQueue.main.async {
                guard let self, gen == self.generation else {
                    return
                }
                self.matches = result.matches
                self.truncated = result.truncated
                self.selection = result.matches.isEmpty ? nil : 0
                self.running = false
            }
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
