import Foundation

final class CheckService: ObservableObject {
    static let shared = CheckService()
    @Published var diagnostics: [Diagnostic] = []
    @Published var running = false
    @Published var hasRun = false
    @Published var failure: String?
    var onFinished: (([Diagnostic]) -> Void)?
    private let queue = DispatchQueue(label: "dev.ride.check")
    private var generation: UInt64 = 0
    private var pending: DispatchWorkItem?

    var errorCount: Int {
        diagnostics.filter { $0.level == .error }.count
    }

    var warningCount: Int {
        diagnostics.filter { $0.level == .warning }.count
    }

    func schedule(root: URL, delay: TimeInterval = 1.5) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.run(root: root)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func run(root: URL) {
        pending?.cancel()
        guard let engine = RideEngineClient.shared.engine else {
            return
        }
        generation += 1
        let gen = generation
        running = true
        queue.async { [weak self] in
            let result = Result { try engine.runCheck(projectRoot: root.path) }
            DispatchQueue.main.async {
                self?.finish(result, generation: gen)
            }
        }
    }

    private func finish(_ result: Result<CheckResult, Error>, generation gen: UInt64) {
        guard gen == generation else {
            return
        }
        running = false
        hasRun = true
        switch result {
        case .success(let check):
            diagnostics = check.diagnostics.filter { $0.level == .error || $0.level == .warning }
            failure = check.success || !diagnostics.isEmpty ? nil : lastLine(check.stderrTail)
            onFinished?(diagnostics)
        case .failure(let error):
            failure = "\(error)"
        }
    }

    private func lastLine(_ text: String) -> String? {
        text.split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
