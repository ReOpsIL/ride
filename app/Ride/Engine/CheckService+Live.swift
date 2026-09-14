import Foundation

extension CheckService {
    static let liveDelay: TimeInterval = 0.8
    static let livePrefix = "live:"
    static let liveCargoSource = "live-cargo"

    func scheduleLive(file: URL, text: String, delay: TimeInterval = CheckService.liveDelay) {
        let path = file.path
        liveTimers[path]?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.runLive(path: path, text: text) }
        liveTimers[path] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func scheduleLiveCargo(root: URL, clippy: Bool, delay: TimeInterval = CheckService.liveDelay) {
        liveTimers[Self.liveCargoSource]?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.runLiveCargo(root: root, clippy: clippy) }
        liveTimers[Self.liveCargoSource] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func setLive(path: String, diagnostics items: [StoredDiagnostic]) {
        store.replaceLive(path: path, with: items)
        hasRun = true
        publish()
        onLiveFinished?(diagnostics)
    }

    func setLive(path: String, diagnostics items: [StoredDiagnostic], generation gen: UInt64) {
        guard generations[Self.livePrefix + path] == gen else { return }
        setLive(path: path, diagnostics: items)
    }

    private func runLive(path: String, text: String) {
        guard let engine = RideEngineClient.shared.engine else { return }
        let source = Self.livePrefix + path
        let gen = bump(source)
        queue.async { [weak self] in
            let result = Result { try engine.checkCLive(path: path, text: text) }
            DispatchQueue.main.async { self?.finishLive(result, path: path, source: source, generation: gen) }
        }
    }

    private func finishLive(
        _ result: Result<CheckResult, Error>,
        path: String,
        source: String,
        generation gen: UInt64
    ) {
        guard generations[source] == gen, case let .success(check) = result else { return }
        let mine = check.diagnostics.compactMap(CheckConvert.stored).filter { $0.path == path }
        setLive(path: path, diagnostics: mine)
    }

    private func runLiveCargo(root: URL, clippy: Bool) {
        guard let engine = RideEngineClient.shared.engine else { return }
        let gen = bump(Self.liveCargoSource)
        queue.async { [weak self] in
            let result = Result { try engine.runCheck(projectRoot: root.path, clippy: clippy) }
            DispatchQueue.main.async { self?.finishLiveCargo(result, generation: gen) }
        }
    }

    private func finishLiveCargo(_ result: Result<CheckResult, Error>, generation gen: UInt64) {
        guard generations[Self.liveCargoSource] == gen, case let .success(check) = result else { return }
        store.replaceLiveCargo(check.diagnostics.compactMap(CheckConvert.stored))
        hasRun = true
        publish()
        onLiveFinished?(diagnostics)
    }
}
