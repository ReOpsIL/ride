import Foundation

final class RideEngineClient: ObservableObject {
    static let shared = RideEngineClient()

    @Published var indexLabel = "idle"
    @Published var indexDetail: String?
    @Published var rustSrcAvailable = false
    @Published var indexProgress: Double?
    @Published var statusKnown = false
    @Published var oracleStatus = OracleStatus(state: .off, message: nil)

    private(set) var engine: Engine?
    private(set) var openRoot: URL?
    private let workspaceQueue = DispatchQueue(label: "dev.ride.workspace", qos: .userInitiated)
    private var listener: StatusForwarder?
    private var oracleListener: OracleForwarder?
    private var semantic: Bool?
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
            offlineMetadata: true,
            refsDir: DemoRefsDir.prepare(),
            reportDir: ReportPaths.directory.path
        )
        let engine = engineStart(config: config)
        let listener = StatusForwarder(client: self)
        engine.setStatusListener(listener: listener)
        self.listener = listener
        let oracleListener = OracleForwarder(client: self)
        engine.setOracleListener(listener: oracleListener)
        self.oracleListener = oracleListener
        self.engine = engine
        apply(engine.status())
    }

    @discardableResult
    func withEngine<T>(
        qos: DispatchQoS.QoSClass = .userInitiated,
        _ work: @escaping (Engine) -> T,
        then done: @escaping (T) -> Void
    ) -> Bool {
        guard let engine else {
            return false
        }
        DispatchQueue.global(qos: qos).async {
            let value = work(engine)
            DispatchQueue.main.async {
                done(value)
            }
        }
        return true
    }

    func openWorkspace(_ url: URL, then completion: (() -> Void)? = nil) {
        guard let engine else {
            return
        }
        openRoot = url
        let indexDir = indexDir
        workspaceQueue.async {
            _ = try? engine.openWorkspace(path: url.path)
            IndexerProcess.run(project: url, indexDir: indexDir)
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    func setSemantic(_ enabled: Bool) {
        guard let engine, semantic != enabled else {
            return
        }
        semantic = enabled
        workspaceQueue.async {
            engine.setOracleEnabled(enabled: enabled)
        }
    }

    func closeWorkspace() {
        guard let engine, openRoot != nil else {
            return
        }
        openRoot = nil
        workspaceQueue.async {
            engine.closeWorkspace()
        }
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
