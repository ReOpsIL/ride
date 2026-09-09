import AppKit
import SwiftUI

final class AppState: ObservableObject {
    @Published var workspaceRoot: URL?
    @Published var rootNodes: [FileNode] = []
    @Published var selectedURL: URL?
    @Published var expanded: Set<URL> = []
    @Published var recent: [URL] = []
    @Published var buffers: [BufferDocument] = []
    @Published var activeID: UUID?
    @Published var cursorLine = 1
    @Published var cursorColumn = 1
    @Published var prefs = Preferences.defaults
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

    init() {
        prefs = PreferencesStore.load()
        recent = recents.load()
        watcher.handler = { [weak self] in
            self?.reloadTree()
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
    }

    static func launchFolder() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--open"), args.indices.contains(i + 1) {
            let url = URL(fileURLWithPath: args[i + 1])
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        if let path = ProcessInfo.processInfo.environment["RIDE_OPEN"] {
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return nil
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
        CompletionSession.shared.hide()
        reloadTree()
        watcher.start(path: url.path)
        RideEngineClient.shared.openWorkspace(url)
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

func cargoPackageName(_ root: URL) -> String? {
    let url = root.appendingPathComponent("Cargo.toml")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        return nil
    }
    for line in text.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("name") else {
            continue
        }
        guard let first = trimmed.firstIndex(of: "\""),
              let last = trimmed.lastIndex(of: "\""),
              first < last
        else {
            continue
        }
        return String(trimmed[trimmed.index(after: first) ..< last])
    }
    return nil
}
