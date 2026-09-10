import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject {
    @Published var workspaceRoot: URL? {
        didSet { syncMenu() }
    }
    @Published var rootNodes: [FileNode] = []
    @Published var selectedURL: URL?
    @Published var expanded: Set<URL> = []
    @Published var recent: [URL] = [] {
        didSet { menu.recent = recent }
    }
    @Published var buffers: [BufferDocument] = [] {
        didSet { syncMenu() }
    }
    @Published var activeID: UUID? {
        didSet { syncMenu() }
    }
    @Published var cursorLine = 1
    @Published var cursorColumn = 1
    @Published var prefs = Preferences.defaults {
        didSet { syncMenu() }
    }
    @Published var showQuickOpen = false
    @Published var showFind = false
    @Published var quickQuery = ""
    @Published var quickHits: [URL] = []
    @Published var quickSelection: URL?
    @Published var findQuery = ""
    @Published var replaceQuery = ""
    @Published var findRange: NSRange?
    @Published var applyText: String?
    @Published var showSymbolInFile = false
    @Published var symbolQuery = ""
    @Published var symbolSelection: UInt32?
    @Published var showSymbolPicker = false
    @Published var showProjectFind = false
    @Published var showProblems = false {
        didSet { syncMenu() }
    }
    @Published var showSidebar = true {
        didSet { syncMenu() }
    }
    @Published var showPreview = false
    @Published var formatError: String?
    @Published var notice: String?
    @Published var noticeAction: (title: String, run: () -> Void)?
    @Published var showToolsSheet = false
    var noticeWork: DispatchWorkItem?
    @Published var showGoToLine = false
    @Published var goToLineQuery = ""
    @Published var showRecentFiles = false
    @Published var recentQuery = ""
    @Published var recentSelection: URL?
    @Published var findOptions = FindOptions.defaults
    @Published var showReplaceField = false
    var recentFiles: [URL] = []
    var zoomBefore = 0
    let history = NavigationHistory()
    let symbolPicker = SymbolPickerModel()
    let projectFind = ProjectFindModel()
    let preview = PreviewModel()
    let git = GitStatusService()
    let menu = MenuModel()
    var pendingJump: UInt32?
    var applyThenSave = false
    var cargoWork: DispatchWorkItem?
    var gitSink: AnyCancellable?
    var layoutSaveWork: DispatchWorkItem?
    var persistLayout = true

    private let recents = RecentProjects()
    private let watcher = FileWatcher()
    var untitledSeq = 0
    var autoSaveWork: DispatchWorkItem?
    var quickFiles: [URL] = []
    var findOrigin = 0
    var queryCounter: UInt64 = 0
    var latestQueryId: UInt64 = 0

    var activeBuffer: BufferDocument? {
        buffers.first { $0.id == activeID }
    }

    func syncMenu() {
        menu.sync(from: self)
    }

    init() {
        prefs = PreferencesStore.load()
        recent = recents.load()
        menu.recent = recent
        ThemeStore.shared.apply(name: prefs.theme)
        watcher.handler = { [weak self] paths in
            self?.filesChanged(paths)
        }
        gitSink = git.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        CheckService.shared.onFinished = { [weak self] diagnostics in
            self?.checkFinished(diagnostics)
        }
        _ = RideEngineClient.shared
        NotificationCenter.default.addObserver(
            forName: .rideOpenCatalog,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let url = note.object as? URL {
                self?.openFile(url, readOnly: CatalogPath.isCatalog(url))
            }
        }
        if let url = Self.launchFolder() {
            open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkTools()
        }
    }

    var windowTitle: String {
        guard let root = workspaceRoot else {
            return "Ride"
        }
        return cargoPackageName(root) ?? root.lastPathComponent
    }

    var relativePath: String {
        if let url = activeBuffer?.fileURL, let root = workspaceRoot {
            return WorkspaceFS.relativePath(root: root, file: url)
        }
        if let active = activeBuffer {
            return active.displayName
        }
        guard let root = workspaceRoot, let selected = selectedURL else {
            return "—"
        }
        return WorkspaceFS.relativePath(root: root, file: selected)
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Open a Cargo project or folder"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        open(url)
    }

    func open(_ url: URL) {
        workspaceRoot = url.standardizedFileURL
        selectedURL = nil
        for buffer in buffers {
            SessionService.shared.close(buffer)
        }
        buffers = []
        activeID = nil
        cursorLine = 1
        cursorColumn = 1
        expanded = []
        recent = recents.adding(url, to: recent)
        recents.save(recent)
        quickFiles = []
        showQuickOpen = false
        CompletionSession.shared.reset()
        reloadTree()
        watcher.start(path: url.path)
        RideEngineClient.shared.openWorkspace(url)
        git.clear()
        git.refresh(root: url, delay: 0)
    }

    func reindex() {
        guard let root = workspaceRoot else {
            return
        }
        IndexerProcess.run(project: root, indexDir: RideEngineClient.shared.indexDir, force: true)
    }

    func updatePrefs(_ edit: (inout Preferences) -> Void) {
        let before = prefs
        edit(&prefs)
        prefs = prefs.clamped
        PreferencesStore.save(prefs)
        if before.showHidden != prefs.showHidden {
            quickFiles = []
            reloadTree()
        }
        if before.theme != prefs.theme {
            applyTheme()
        }
    }

    func reloadTree() {
        guard let root = workspaceRoot else {
            rootNodes = []
            return
        }
        rootNodes = WorkspaceFS.children(of: root, showHidden: prefs.showHidden)
        restoreExpanded(rootNodes)
    }

    private func restoreExpanded(_ nodes: [FileNode]) {
        for node in nodes where node.isDirectory && expanded.contains(node.url) {
            node.loadChildren()
            restoreExpanded(node.children)
        }
    }
}
