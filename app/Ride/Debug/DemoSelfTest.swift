import AppKit

final class DemoSelfTest {
    static let shared = DemoSelfTest()
    private var results: [String] = []
    private var steps: [SelfTestStep] = []
    private var report = ""

    static func start(state: AppState, report: String) {
        let selection = SelfTestSelection.pick(SelfTestSteps.all(state: state), only: DemoLaunch.only, name: \.name)
        shared.report = report
        shared.results = selection.missing.map { "FAIL only: no step named \($0)" }
        shared.writeReport()
        shared.steps = selection.picked
        shared.next(state: state)
    }

    private func next(state: AppState) {
        guard !steps.isEmpty else {
            finish()
            return
        }
        let step = steps.removeFirst()
        step.run()
        settle(step, state: state, deadline: Date().addingTimeInterval(step.timeout))
    }

    private func settle(_ step: SelfTestStep, state: AppState, deadline: Date) {
        DemoLaunch.after(step.wait) { [self] in
            if let until = step.until, !until(), Date() < deadline {
                settle(step, state: state, deadline: deadline)
                return
            }
            if let failure = step.check() {
                let e = SelfTestEditor(state: state)
                let dump = (8...13).map { "\($0): \(e.line($0))" }.joined(separator: " ¶ ")
                results.append("FAIL \(step.name): \(failure) || \(dump)")
            } else {
                results.append("PASS \(step.name)")
            }
            writeReport()
            next(state: state)
        }
    }

    var passedNames: Set<String> {
        Set(results.compactMap { $0.hasPrefix("PASS ") ? String($0.dropFirst(5)) : nil })
    }

    func attach(name: String, text: String) {
        let url = URL(fileURLWithPath: report).deletingLastPathComponent().appendingPathComponent(name)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func finish() {
        let code = results.contains(where: { $0.hasPrefix("FAIL") }) ? 1 : 0
        results.append("EXIT \(code)")
        writeReport()
        NSApp.terminate(nil)
    }

    private func writeReport() {
        let url = URL(fileURLWithPath: report)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let text = results.joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
