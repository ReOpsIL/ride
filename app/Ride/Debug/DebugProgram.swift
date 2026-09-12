import Foundation

struct DebugProgram: Equatable {
    var program: String
    var args: [String]

    static func resolve(
        plan: RunPlan,
        kind: RunProjectKind,
        targetName: String,
        workingDir: String,
        profile: String
    ) -> DebugProgram? {
        guard kind == .cargo else {
            guard let first = plan.argv.first, !first.isEmpty else {
                return nil
            }
            return DebugProgram(program: first, args: Array(plan.argv.dropFirst()))
        }
        guard !targetName.isEmpty, !workingDir.isEmpty else {
            return nil
        }
        let directory = profile.isEmpty || profile == "debug" ? "debug" : profile
        let binary = URL(fileURLWithPath: workingDir)
            .appendingPathComponent("target")
            .appendingPathComponent(directory)
            .appendingPathComponent(targetName)
        return DebugProgram(program: binary.path, args: passthrough(plan.argv))
    }

    private static func passthrough(_ argv: [String]) -> [String] {
        guard let separator = argv.firstIndex(of: "--") else {
            return []
        }
        return Array(argv.suffix(from: argv.index(after: separator)))
    }
}
