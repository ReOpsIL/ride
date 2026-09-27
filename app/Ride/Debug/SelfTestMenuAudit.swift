import Foundation

struct SelfTestMenuAudit {
    let paths: [String]
    let claims: [String: [String]]
    let exempt: [String: String]
    let known: Set<String>
    let suite: Set<String>
    let passed: Set<String>

    var problems: [String] {
        let uncovered = paths.filter { claims[$0] == nil && exempt[$0] == nil }.map { "uncovered \($0)" }
        let unknown = claims.flatMap { path, steps in
            steps.filter { !known.contains($0) }.map { "\(path) claims unknown step '\($0)'" }
        }
        let failed = claims.flatMap { path, steps in
            steps.filter { suite.contains($0) && !passed.contains($0) }.map { "\(path) step '\($0)' did not pass" }
        }
        return uncovered + unknown.sorted() + failed.sorted()
    }

    var stale: [String] {
        Set(claims.keys).union(exempt.keys).subtracting(paths).sorted()
    }

    var listing: String {
        let rows = paths.map { path in
            if let steps = claims[path] {
                return "COVERED \(path) <- \(steps.joined(separator: ", "))"
            }
            if let reason = exempt[path] {
                return "EXEMPT  \(path) (\(reason))"
            }
            return "MISSING \(path)"
        }
        return (rows + stale.map { "ABSENT  \($0) (not in this run's menus)" }).joined(separator: "\n") + "\n"
    }
}
