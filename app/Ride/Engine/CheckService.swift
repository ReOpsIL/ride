import Foundation

final class CheckService: ObservableObject {
    static let shared = CheckService()
    static let cargoSource = "cargo"
    @Published var diagnostics: [Diagnostic] = []
    @Published var running = false
    @Published var hasRun = false
    @Published var failure: String?
    @Published var stderrTail = ""
    @Published private(set) var version: UInt64 = 0
    var onFinished: (([Diagnostic]) -> Void)?
    private let queue = DispatchQueue(label: "dev.ride.check")
    private var bySource: [String: [Diagnostic]] = [:]
    private var generations: [String: UInt64] = [:]
    private var pending: DispatchWorkItem?

    var errorCount: Int {
        diagnostics.filter { $0.level == .error }.count
    }

    var warningCount: Int {
        diagnostics.filter { $0.level == .warning }.count
    }

    func schedule(root: URL, delay: TimeInterval = 1.5) {
        schedule(delay: delay) { [weak self] in
            self?.run(root: root)
        }
    }

    func schedule(file: URL, delay: TimeInterval = 1.5) {
        schedule(delay: delay) { [weak self] in
            self?.run(file: file)
        }
    }

    func run(root: URL) {
        start(source: Self.cargoSource) { engine in
            try engine.runCheck(projectRoot: root.path)
        }
    }

    func run(file: URL) {
        start(source: file.path) { engine in
            try engine.runCheckC(path: file.path)
        }
    }

    private func schedule(delay: TimeInterval, _ body: @escaping () -> Void) {
        pending?.cancel()
        let work = DispatchWorkItem(block: body)
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func start(source: String, _ job: @escaping (Engine) throws -> CheckResult) {
        pending?.cancel()
        guard let engine = RideEngineClient.shared.engine else {
            return
        }
        let gen = (generations[source] ?? 0) + 1
        generations[source] = gen
        running = true
        queue.async { [weak self] in
            let result = Result { try job(engine) }
            DispatchQueue.main.async {
                self?.finish(result, source: source, generation: gen)
            }
        }
    }

    private func finish(_ result: Result<CheckResult, Error>, source: String, generation gen: UInt64) {
        guard generations[source] == gen else {
            return
        }
        running = false
        hasRun = true
        switch result {
        case .success(let check):
            let mine = check.diagnostics.filter { $0.level == .error || $0.level == .warning }
            bySource[source] = mine
            version += 1
            diagnostics = bySource.values.flatMap { $0 }.sorted { ($0.path, $0.byteStart) < ($1.path, $1.byteStart) }
            failure = check.success || !mine.isEmpty ? nil : lastLine(check.stderrTail)
            stderrTail = failure == nil ? "" : check.stderrTail
            onFinished?(diagnostics)
        case .failure(let error):
            failure = "\(error)"
            stderrTail = ""
        }
    }

    private func lastLine(_ text: String) -> String? {
        text.split(separator: "\n").last.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
