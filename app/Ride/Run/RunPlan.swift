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
    var prelude: [String]?

    init(argv: [String], env: [String: String], cwd: String?, prelude: [String]? = nil) {
        self.argv = argv
        self.env = env
        self.cwd = cwd
        self.prelude = prelude
    }
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
        let variant = RunVariant(
            kind: kind,
            profile: profile,
            sanitizers: config.activeSanitizers(for: kind),
            targets: targets + (target.map { [$0] } ?? [])
        )
        guard let base = resolve(action, target: target, targets: targets, variant: variant) else {
            return nil
        }
        let argv = variant.argv(base.argv) + extraArgs(action, kind: kind, config: config, argv: base.argv)
        var env = variant.env
        for (key, value) in config.env {
            env[key] = value
        }
        if config.rustBacktrace {
            env["RUST_BACKTRACE"] = "1"
        }
        let cwd = config.workingDir.flatMap { $0.isEmpty ? nil : $0 } ?? base.workingDir
        let prelude = action == .build ? variant.configure(source: base.workingDir) : nil
        return RunPlan(argv: argv, env: env, cwd: cwd.isEmpty ? nil : cwd, prelude: prelude)
    }

    static func testTarget(_ targets: [RunTarget]) -> RunTarget? {
        targets.first { $0.kind == .test && !$0.build.isEmpty }
    }

    private static func extraArgs(_ action: RunAction, kind: RunProjectKind, config: RunConfig, argv: [String]) -> [String] {
        switch action {
        case .build, .test:
            return config.buildArgs
        case .run:
            let build = kind == .cargo && argv.first == "cargo" ? config.buildArgs : []
            guard !config.args.isEmpty else {
                return build
            }
            let separator = argv.first == "cargo" && !argv.contains("--") ? ["--"] : []
            return build + separator + config.args
        }
    }

    private static func resolve(
        _ action: RunAction,
        target: RunTarget?,
        targets: [RunTarget],
        variant: RunVariant
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
            guard let argv = fallbackTest(variant: variant, targets: targets) else {
                return nil
            }
            return (argv, target?.workingDir ?? targets.first?.workingDir ?? "")
        }
    }

    private static func fallbackTest(variant: RunVariant, targets: [RunTarget]) -> [String]? {
        switch variant.kind {
        case .cargo:
            return ["cargo", "test"]
        case .cmake:
            let fallback = variant.profile.isEmpty ? "build" : "build/\(variant.profile)"
            return ["ctest", "--test-dir", variant.engineDir ?? fallback]
        case .make:
            return targets.contains { $0.name == "test" } ? ["make", "test"] : nil
        case .compileDb, .none:
            return nil
        }
    }
}
