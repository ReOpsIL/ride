import Foundation

enum RunRequests {
    static func request(_ action: RunAction, plan: RunPlan, kind: RunProjectKind, root: String) -> RunRequest {
        let main = step(action, plan: plan, kind: kind, root: root)
        guard let prelude = plan.prelude else {
            return main
        }
        return RunRequest(
            invocation: RunInvocation(argv: prelude, workingDir: plan.cwd, env: plan.env),
            session: .build(kind: kind, baseDir: plan.cwd ?? root),
            then: .run(main)
        )
    }

    private static func step(_ action: RunAction, plan: RunPlan, kind: RunProjectKind, root: String) -> RunRequest {
        switch action {
        case .build:
            let argv = kind == .cargo ? BuildParse.cargoArgv(plan.argv) : plan.argv
            return RunRequest(
                invocation: RunInvocation(argv: argv, workingDir: plan.cwd, env: plan.env),
                session: .build(kind: kind, baseDir: plan.cwd ?? root)
            )
        case .test:
            return RunRequest(
                invocation: RunInvocation(argv: plan.argv, workingDir: plan.cwd, env: plan.env),
                session: .tests(framework: nil)
            )
        case .run:
            return .plain(RunInvocation(argv: plan.argv, workingDir: plan.cwd, env: plan.env))
        }
    }
}
