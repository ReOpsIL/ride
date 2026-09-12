import Foundation

final class MenuModel: ObservableObject {
    @Published var recent: [URL] = []
    @Published var previewAvailable = false
    @Published var hasEditor = false
    @Published var hasWorkspace = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var softWrap = true
    @Published var visibleWhitespace = false
    @Published var indentGuides = true
    @Published var showSidebar = true
    @Published var outlinePanel = true
    @Published var showProblems = false
    @Published var showRunOutput = false
    @Published var showTerminal = false
    @Published var showTests = false
    @Published var isRunning = false
    @Published var hasSplit = false
    @Published var selectedTarget: String?
    @Published var canBuild = false
    @Published var canRunTarget = false
    @Published var canRunTests = false
    @Published var canRunFile = false
    @Published var canRecompileFile = false
    @Published var canDebug = false
    @Published var isDebugging = false
    @Published var isDebugStopped = false
    @Published var isDebugRunning = false
    @Published var showDebugPanel = false
    @Published var debugFilters: [DebugFilterToggle] = []

    func sync(from state: AppState) {
        set(\.previewAvailable, state.previewAvailable)
        set(\.hasEditor, state.activeBuffer != nil)
        set(\.hasWorkspace, state.workspaceRoot != nil)
        set(\.canGoBack, state.history.canGoBack)
        set(\.canGoForward, state.history.canGoForward)
        set(\.softWrap, state.prefs.softWrap)
        set(\.visibleWhitespace, state.prefs.visibleWhitespace)
        set(\.indentGuides, state.prefs.indentGuides)
        set(\.showSidebar, state.showSidebar)
        set(\.outlinePanel, state.prefs.outlinePanel)
        set(\.showProblems, state.showProblems)
        set(\.showRunOutput, state.showRunOutput)
        set(\.showTerminal, state.showTerminal)
        set(\.showTests, state.showTests)
        set(\.isRunning, state.runOutput.isRunning)
        set(\.hasSplit, state.splitLayout.isSplit)
        set(\.selectedTarget, state.projectModel.selected?.name)
        set(\.canBuild, state.canRun(.build))
        set(\.canRunTarget, state.canRun(.run))
        set(\.canRunTests, state.canRun(.test))
        set(\.canRunFile, state.canRunFile)
        set(\.canRecompileFile, state.canRecompileFile)
        set(\.canDebug, state.canDebug)
        set(\.isDebugging, state.debug.isActive)
        set(\.isDebugStopped, state.debug.isStopped)
        set(\.isDebugRunning, state.debug.isRunning)
        set(\.showDebugPanel, state.debugPanel.visible)
        set(\.debugFilters, DebugFilters.shared.toggles)
    }

    private func set<T: Equatable>(_ path: ReferenceWritableKeyPath<MenuModel, T>, _ value: T) {
        if self[keyPath: path] != value {
            self[keyPath: path] = value
        }
    }
}
