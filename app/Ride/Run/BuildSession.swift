import Foundation

final class BuildSession {
    static let shared = BuildSession()

    private var kind = RunProjectKind.none
    private var baseDir = ""
    private var cargo: [Diagnostic] = []
    private var text = ""
    private var active = false

    func begin(kind: RunProjectKind, baseDir: String) {
        self.kind = kind
        self.baseDir = baseDir
        cargo = []
        text = ""
        active = true
    }

    func cancel() {
        active = false
    }

    func line(_ line: String) -> String? {
        guard active else {
            return line
        }
        guard kind == .cargo else {
            text += line + "\n"
            return line
        }
        guard BuildParse.isMessage(line) else {
            return line
        }
        cargo += RideEngineClient.shared.engine?.parseCargoLine(line: line) ?? []
        return BuildParse.rendered(line)
    }

    func finish() {
        guard active else {
            return
        }
        active = false
        CheckService.shared.replaceBuild(diagnostics())
    }

    private func diagnostics() -> [Diagnostic] {
        guard kind != .cargo else {
            return cargo
        }
        guard let engine = RideEngineClient.shared.engine else {
            return []
        }
        return engine.parseClangOutput(text: text, baseDir: baseDir)
    }
}
