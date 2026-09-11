import Foundation

final class CheckService: ObservableObject {
    static let shared = CheckService()
    static let cargoSource = "cargo"
    static let projectSource = "clang-project"
    @Published var diagnostics: [Diagnostic] = []
    @Published var running = false
    @Published var hasRun = false
    @Published var failure: String?
    @Published var stderrTail = ""
    @Published var progress = ""
    @Published private(set) var version: UInt64 = 0
    var onFinished: (([Diagnostic]) -> Void)?
    private let queue = DispatchQueue(label: "dev.ride.check")
    private var store = DiagnosticStore()
    private var generations: [String: UInt64] = [:]
    private var pending: DispatchWorkItem?

    var snapshot: [StoredDiagnostic] { store.snapshot }
    var clangPaths: [String] { store.clangPaths }
    var errorCount: Int { diagnostics.filter { $0.level == .error }.count }
    var warningCount: Int { diagnostics.filter { $0.level == .warning }.count }

    func schedule(root: URL, delay: TimeInterval = 1.5) {
        schedule(delay: delay) { [weak self] in self?.run(root: root) }
    }

    func schedule(file: URL, delay: TimeInterval = 1.5) {
        schedule(delay: delay) { [weak self] in self?.run(file: file) }
    }

    func scheduleIncluding(header: URL, delay: TimeInterval = 1.5) {
        schedule(delay: delay) { [weak self] in self?.runIncluding(header: header) }
    }

    func run(root: URL) {
        start(source: Self.cargoSource, progress: "Checking…") { engine in
            try engine.runCheck(projectRoot: root.path)
        }
    }

    func run(file: URL) {
        start(source: file.path, progress: "Checking…") { engine in
            try engine.runCheckC(path: file.path)
        }
    }

    func runProject(root: URL) {
        start(source: Self.projectSource, progress: "Checking project…") { engine in
            try engine.runCheckCProject(root: root.path)
        }
    }

    func runIncluding(header: URL) {
        guard let engine = RideEngineClient.shared.engine else { return }
        let source = header.path
        let gen = bump(source)
        begin(progress: "Checking…")
        queue.async { [weak self] in
            let paths = engine.sourcesIncluding(header: header.path)
            let results = paths.map { path in
                (path, Result { try engine.runCheckC(path: path) })
            }
            DispatchQueue.main.async {
                self?.finishIncluding(results, source: source, generation: gen)
            }
        }
    }

    func dropClang(path: String) {
        dropClang(paths: [path])
    }

    func dropClang(paths: [String]) {
        var any = false
        for path in paths {
            any = store.remove(path: path) || any
        }
        if any {
            publish()
        }
    }

    private func schedule(delay: TimeInterval, _ body: @escaping () -> Void) {
        pending?.cancel()
        let work = DispatchWorkItem(block: body)
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func bump(_ source: String) -> UInt64 {
        let gen = (generations[source] ?? 0) + 1
        generations[source] = gen
        return gen
    }

    private func begin(progress: String) {
        pending?.cancel()
        running = true
        self.progress = progress
    }

    private func start(source: String, progress: String, _ job: @escaping (Engine) throws -> CheckResult) {
        guard let engine = RideEngineClient.shared.engine else { return }
        let gen = bump(source)
        begin(progress: progress)
        queue.async { [weak self] in
            let result = Result { try job(engine) }
            DispatchQueue.main.async {
                self?.finish(result, source: source, generation: gen)
            }
        }
    }

    private func finish(_ result: Result<CheckResult, Error>, source: String, generation gen: UInt64) {
        guard generations[source] == gen else { return }
        running = false
        progress = ""
        hasRun = true
        switch result {
        case .success(let check):
            let mine = check.diagnostics.compactMap(CheckConvert.stored)
            if source == Self.cargoSource {
                store.replaceCargo(mine)
            } else if source == Self.projectSource {
                store.replaceAllClang(from: source, with: mine)
            } else {
                store.replace(from: source, with: mine)
            }
            publish()
            failure = check.success || !mine.isEmpty ? nil : CheckConvert.lastLine(check.stderrTail)
            stderrTail = failure == nil ? "" : check.stderrTail
            onFinished?(diagnostics)
        case .failure(let error):
            failure = "\(error)"
            stderrTail = ""
        }
    }

    private func finishIncluding(
        _ results: [(String, Result<CheckResult, Error>)],
        source: String,
        generation gen: UInt64
    ) {
        guard generations[source] == gen else { return }
        running = false
        progress = ""
        hasRun = true
        var lastFail: String?
        var tail = ""
        for (path, result) in results {
            switch result {
            case .success(let check):
                store.replace(from: path, with: check.diagnostics.compactMap(CheckConvert.stored))
                if !check.success, check.diagnostics.isEmpty {
                    lastFail = CheckConvert.lastLine(check.stderrTail)
                    tail = check.stderrTail
                }
            case .failure(let error):
                lastFail = "\(error)"
            }
        }
        publish()
        failure = lastFail
        stderrTail = lastFail == nil ? "" : tail
        onFinished?(diagnostics)
    }

    private func publish() {
        version += 1
        diagnostics = store.snapshot.map(CheckConvert.ffi)
    }
}
