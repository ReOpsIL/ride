import Foundation

final class RideEngineClient: ObservableObject {
    static let shared = RideEngineClient()

    @Published var indexLabel = "idle"
    @Published var indexDetail: String?
    @Published var rustSrcAvailable = false
    @Published var indexProgress: Double?
    @Published var statusKnown = false

    private(set) var engine: Engine?
    private var listener: StatusForwarder?
    let indexDir: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        indexDir = base.appendingPathComponent("Ride/index")
        try? FileManager.default.createDirectory(at: indexDir, withIntermediateDirectories: true)
        start()
    }

    func start() {
        let config = EngineConfig(
            indexDir: indexDir.path,
            cargoHome: nil,
            sysroot: nil,
            offlineMetadata: true
        )
        let engine = engineStart(config: config)
        let listener = StatusForwarder(client: self)
        engine.setStatusListener(listener: listener)
        self.listener = listener
        self.engine = engine
        apply(engine.status())
    }

    func openWorkspace(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, let engine = self.engine else {
                return
            }
            _ = try? engine.openWorkspace(path: url.path)
            IndexerProcess.run(project: url, indexDir: self.indexDir)
        }
    }

    func closeWorkspace() {
        engine?.closeWorkspace()
    }

    func apply(_ status: IndexStatus) {
        statusKnown = true
        rustSrcAvailable = status.rustSrcAvailable
        indexProgress = status.state == .indexing && status.cratesTotal > 0
            ? Double(status.cratesDone) / Double(status.cratesTotal)
            : nil
        indexLabel = IndexStatusLabel.text(status)
        indexDetail = IndexStatusLabel.detail(status)
    }
}

final class StatusForwarder: IndexStatusListener, @unchecked Sendable {
    weak var client: RideEngineClient?

    init(client: RideEngineClient) {
        self.client = client
    }

    func onStatus(status: IndexStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.client?.apply(status)
        }
    }
}
