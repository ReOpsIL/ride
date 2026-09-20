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
    @Published var showTests = false {
        didSet { syncMenu(); scheduleWorkspaceSave() }
    }
    @Published var showUsages = false {
        didSet { syncMenu() }
    }
    @Published var showHierarchy = false {
        didSet { syncMenu() }
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
    var noticeDismiss: (() -> Void)?
    @Published var showToolsSheet = false
    @Published var showNewProjectSheet = false
    @Published var showRunConfigSheet = false
    @Published var showRenamePreview = false
    let renamePreview = RenamePreviewModel()
    var renamePlan: RenamePlan?
    var renameExpected: [String: [String: String]] = [:]
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
    let history = NavigationHistory()
    let symbolPicker = SymbolPickerModel()
    let projectFind = ProjectFindModel()
    let preview = PreviewModel()
    let git = GitStatusService()
    let menu = MenuModel()
    let projectModel = ProjectModelStore()
    let runOutput = RunOutput()
    let testRun = TestRunStore.shared
    let terminals = TerminalStore()
    let usages = UsagesModel.shared
    @Published var hierarchy = HierarchyModel()
    var cargoWork: DispatchWorkItem?
    var gitSink: AnyCancellable?
    var layoutSaveWork: DispatchWorkItem?
    var persistLayout = true
    var restoringWorkspace = false
    let workspaceStore = WorkspaceStateStore()

    let recents = RecentProjects()
    let watcher = FileWatcher()
    var untitledSeq = 0
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
        configure()
    }
}
