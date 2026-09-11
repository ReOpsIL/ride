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
    @Published var hasSplit = false
    @Published var selectedTarget: String?

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
        set(\.hasSplit, state.splitLayout.isSplit)
        set(\.selectedTarget, state.projectModel.selected?.name)
    }

    private func set<T: Equatable>(_ path: ReferenceWritableKeyPath<MenuModel, T>, _ value: T) {
        if self[keyPath: path] != value {
            self[keyPath: path] = value
        }
    }
}
