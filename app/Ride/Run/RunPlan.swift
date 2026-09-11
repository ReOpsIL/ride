import Foundation

enum RunAction: String, CaseIterable {
    case build
    case run
    case test
}

struct RunTarget: Equatable {
    var name: String
    var kind: TargetRowKind
    var build: [String]
    var run: [String]
    var workingDir: String

    init(name: String, kind: TargetRowKind, build: [String] = [], run: [String] = [], workingDir: String = "") {
        self.name = name
        self.kind = kind
        self.build = build
        self.run = run
        self.workingDir = workingDir
    }
}

struct RunPlan: Equatable {
    var argv: [String]
    var env: [String: String]
    var cwd: String?
}

enum RunPlanner {
    static func plan(
        _ action: RunAction,
        target: RunTarget?,
        targets: [RunTarget] = [],
        config: RunConfig,
        kind: RunProjectKind,
        profile: String = ""
    ) -> RunPlan? {
        guard let base = resolve(action, target: target, targets: targets, kind: kind, profile: profile) else {
            return nil
        }
        let flags = config.flags(for: kind)
        var argv = base.argv + (kind == .cargo ? flags.args : [])
        if !config.args.isEmpty {
            argv += separator(action, kind: kind, argv: argv) + config.args
        }
        var env = flags.env
        for (key, value) in config.env {
            env[key] = value
        }
        if config.rustBacktrace {
            env["RUST_BACKTRACE"] = "1"
        }
        let cwd = config.workingDir.flatMap { $0.isEmpty ? nil : $0 } ?? base.workingDir
        return RunPlan(argv: argv, env: env, cwd: cwd.isEmpty ? nil : cwd)
    }

    static func testTarget(_ targets: [RunTarget]) -> RunTarget? {
        targets.first { $0.kind == .test && !$0.build.isEmpty }
    }

    private static func resolve(
        _ action: RunAction,
        target: RunTarget?,
        targets: [RunTarget],
        kind: RunProjectKind,
        profile: String
    ) -> (argv: [String], workingDir: String)? {
        switch action {
        case .build:
            guard let target, !target.build.isEmpty else {
                return nil
            }
            return (target.build, target.workingDir)
        case .run:
            guard let target, !target.run.isEmpty else {
                return nil
            }
            return (target.run, target.workingDir)
        case .test:
            if let test = testTarget(targets) {
                return (test.build, test.workingDir)
            }
            guard let argv = fallbackTest(kind: kind, targets: targets, profile: profile) else {
                return nil
            }
            return (argv, target?.workingDir ?? targets.first?.workingDir ?? "")
        }
    }

    private static func fallbackTest(kind: RunProjectKind, targets: [RunTarget], profile: String) -> [String]? {
        switch kind {
        case .cargo:
            return ["cargo", "test"]
        case .cmake:
            return ["ctest", "--test-dir", profile.isEmpty ? "build" : "build/\(profile)"]
        case .make:
            return targets.contains { $0.name == "test" } ? ["make", "test"] : nil
        case .compileDb, .none:
            return nil
        }
    }

    private static func separator(_ action: RunAction, kind: RunProjectKind, argv: [String]) -> [String] {
        guard action == .run, kind == .cargo, argv.first == "cargo", !argv.contains("--") else {
            return []
        }
        return ["--"]
    }
}
