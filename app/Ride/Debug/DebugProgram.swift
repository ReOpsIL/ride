import Foundation

struct DebugProgram: Equatable {
    var program: String
    var args: [String]

    static func resolve(plan: RunPlan, target: RunTarget, variant: RunVariant) -> DebugProgram? {
        guard variant.kind == .cargo else {
            guard let first = plan.argv.first, !first.isEmpty else {
                return nil
            }
            return DebugProgram(
                program: located(first, base: plan.cwd ?? emptyToNil(target.workingDir)),
                args: Array(plan.argv.dropFirst())
            )
        }
        guard !target.name.isEmpty, !target.workingDir.isEmpty else {
            return nil
        }
        return DebugProgram(program: cargoBinary(target: target, variant: variant), args: passthrough(plan.argv))
    }

    static func cargoBinary(target: RunTarget, variant: RunVariant) -> String {
        let parts = ["target", variant.cargoTriple, variant.cargoProfileDir, target.kind == .example ? "examples" : nil, target.name]
        return parts.compactMap { $0 }.reduce(URL(fileURLWithPath: target.workingDir)) { url, part in
            url.appendingPathComponent(part)
        }.path
    }

    static func located(_ program: String, base: String?) -> String {
        guard !program.hasPrefix("/"), program.contains("/"), let base, !base.isEmpty else {
            return program
        }
        return URL(fileURLWithPath: base)
            .appendingPathComponent(program)
            .standardizedFileURL
            .path
    }

    static func emptyToNil(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }

    private static func passthrough(_ argv: [String]) -> [String] {
        guard let separator = argv.firstIndex(of: "--") else {
            return []
        }
        return Array(argv.suffix(from: argv.index(after: separator)))
    }
}
