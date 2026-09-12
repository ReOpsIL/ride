import AppKit
import Combine
import SwiftUI

final class AppState: ObservableObject {
    @Published var workspaceRoot: URL? {
        didSet { syncMenu(); workspaceRootDidChange() }
    }
    @Published var rootNodes: [FileNode] = []
    @Published var selectedURL: URL?
    @Published var expanded: Set<URL> = []
    @Published var recent: [URL] = [] {
        didSet { menu.recent = recent }
    }
    @Published var buffers: [BufferDocument] = [] {
        didSet { paneLayout.retain(Set(buffers.map(\.id))); syncMenu(); dropClosedClangDiagnostics(from: oldValue); scheduleWorkspaceSave() }
    }
    @Published var paneLayout = PaneLayout() {
        didSet { syncMenu(); scheduleWorkspaceSave() }
    }
    @Published var splitLayout = SplitLayout() {
        didSet { syncMenu(); scheduleWorkspaceSave() }
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
        didSet { syncMenu(); scheduleWorkspaceSave() }
    }
    @Published var showRunOutput = false {
        didSet { syncMenu(); scheduleWorkspaceSave() }
    }
    @Published var showTerminal = false {
        didSet { syncMenu(); scheduleWorkspaceSave() }
    }
    @Published var showSidebar = true {
        didSet { syncMenu(); scheduleWorkspaceSave() }
    }
    @Published var showPreview = false {
        didSet { scheduleWorkspaceSave() }
    }
    @Published var formatError: String?
    @Published var notice: String?
    @Published var noticeAction: (title: String, run: () -> Void)?
    @Published var showToolsSheet = false
    @Published var showRunConfigSheet = false
    @Published var runConfigs: [RunConfig] = [] {
        didSet { scheduleWorkspaceSave() }
    }
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
    let projectModel = ProjectModelStore()
    let runOutput = RunOutput()
    let terminals = TerminalStore()
    var pendingJump: UInt32?
    var applyThenSave = false
    var cargoWork: DispatchWorkItem?
    var gitSink: AnyCancellable?
    var layoutSaveWork: DispatchWorkItem?
    var persistLayout = true
    var restoringWorkspace = false
    let workspaceStore = WorkspaceStateStore()

    let recents = RecentProjects()
    let watcher = FileWatcher()
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
        projectModel.onChange = { [weak self] in
            self?.syncMenu()
        }
        runOutput.onChange = { [weak self] in
            self?.syncMenu()
        }
        runOutput.lineFilter = { BuildSession.shared.line($0) }
        runOutput.onFinish = { _ in BuildSession.shared.finish() }
        CheckService.shared.onFinished = { [weak self] diagnostics in
            self?.checkFinished(diagnostics)
        }
        _ = RideEngineClient.shared
        EditorPanes.shared.onFocus = { [weak self] pane in
            self?.paneFocused(pane)
        }
        watchWorkspaceQuit()
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
        scheduleWorkspaceSave()
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
