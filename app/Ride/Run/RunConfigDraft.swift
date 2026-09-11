import Foundation

struct RunConfigEnvRow: Identifiable, Equatable {
    let id = UUID()
    var key = ""
    var value = ""
}

struct RunConfigDraft {
    var args = ""
    var workingDir = ""
    var rustBacktrace = false
    var sanitizers: Set<Sanitizer> = []
    var env: [RunConfigEnvRow] = []

    init() {}

    init(_ config: RunConfig) {
        args = RunArgs.join(config.args)
        workingDir = config.workingDir ?? ""
        rustBacktrace = config.rustBacktrace
        sanitizers = config.sanitizers
        env = config.env.keys.sorted().map { RunConfigEnvRow(key: $0, value: config.env[$0] ?? "") }
    }

    func config(target: String) -> RunConfig {
        var pairs: [String: String] = [:]
        for row in env where !row.key.isEmpty {
            pairs[row.key] = row.value
        }
        return RunConfig(
            target: target,
            args: RunArgs.split(args),
            env: pairs,
            workingDir: workingDir.isEmpty ? nil : workingDir,
            rustBacktrace: rustBacktrace,
            sanitizers: sanitizers
        )
    }

    func requiresNightly(kind: RunProjectKind) -> Bool {
        config(target: "").requiresNightly(for: kind)
    }
}

enum RunArgs {
    static func split(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        var quote: Character?
        var open = false
        for ch in text {
            if let active = quote {
                if ch == active {
                    quote = nil
                } else {
                    current.append(ch)
                }
                continue
            }
            if ch == "\"" || ch == "'" {
                quote = ch
                open = true
                continue
            }
            if ch == " " {
                if !current.isEmpty || open {
                    out.append(current)
                }
                current = ""
                open = false
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty || open {
            out.append(current)
        }
        return out
    }

    static func join(_ args: [String]) -> String {
        args.map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: " ")
    }
}
