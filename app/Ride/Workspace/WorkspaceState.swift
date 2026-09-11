import Foundation

struct TabState: Codable, Equatable {
    var path: String
    var caretByte: UInt32
    var scrollLine: UInt32
    var folds: [UInt32]

    init(path: String, caretByte: UInt32, scrollLine: UInt32, folds: [UInt32]) {
        self.path = path
        self.caretByte = caretByte
        self.scrollLine = scrollLine
        self.folds = folds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        caretByte = try c.decodeIfPresent(UInt32.self, forKey: .caretByte) ?? 0
        scrollLine = try c.decodeIfPresent(UInt32.self, forKey: .scrollLine) ?? 1
        folds = try c.decodeIfPresent([UInt32].self, forKey: .folds) ?? []
    }

    func clamped(toUtf8Count count: Int) -> TabState {
        var next = self
        next.caretByte = min(caretByte, UInt32(max(0, count)))
        next.scrollLine = max(1, scrollLine)
        next.folds = folds.filter { Int($0) < count }
        return next
    }

    func folds(keeping valid: Set<UInt32>) -> [UInt32] {
        folds.filter { valid.contains($0) }
    }
}

struct LayoutState: Codable, Equatable {
    var sidebarWidth: Double
    var outlineWidth: Double
    var problemsHeight: Double
    var runOutputHeight: Double
    var previewWidth: Double
    var showSidebar: Bool
    var showProblems: Bool
    var showRunOutput: Bool
    var showPreview: Bool
    var outlinePanel: Bool

    static let defaults = LayoutState(
        sidebarWidth: 230,
        outlineWidth: 220,
        problemsHeight: 180,
        runOutputHeight: 200,
        previewWidth: 460,
        showSidebar: true,
        showProblems: false,
        showRunOutput: false,
        showPreview: false,
        outlinePanel: true
    )

    init(
        sidebarWidth: Double,
        outlineWidth: Double,
        problemsHeight: Double,
        runOutputHeight: Double,
        previewWidth: Double,
        showSidebar: Bool,
        showProblems: Bool,
        showRunOutput: Bool,
        showPreview: Bool,
        outlinePanel: Bool
    ) {
        self.sidebarWidth = sidebarWidth
        self.outlineWidth = outlineWidth
        self.problemsHeight = problemsHeight
        self.runOutputHeight = runOutputHeight
        self.previewWidth = previewWidth
        self.showSidebar = showSidebar
        self.showProblems = showProblems
        self.showRunOutput = showRunOutput
        self.showPreview = showPreview
        self.outlinePanel = outlinePanel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LayoutState.defaults
        sidebarWidth = try c.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? d.sidebarWidth
        outlineWidth = try c.decodeIfPresent(Double.self, forKey: .outlineWidth) ?? d.outlineWidth
        problemsHeight = try c.decodeIfPresent(Double.self, forKey: .problemsHeight) ?? d.problemsHeight
        runOutputHeight = try c.decodeIfPresent(Double.self, forKey: .runOutputHeight) ?? d.runOutputHeight
        previewWidth = try c.decodeIfPresent(Double.self, forKey: .previewWidth) ?? d.previewWidth
        showSidebar = try c.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? d.showSidebar
        showProblems = try c.decodeIfPresent(Bool.self, forKey: .showProblems) ?? d.showProblems
        showRunOutput = try c.decodeIfPresent(Bool.self, forKey: .showRunOutput) ?? d.showRunOutput
        showPreview = try c.decodeIfPresent(Bool.self, forKey: .showPreview) ?? d.showPreview
        outlinePanel = try c.decodeIfPresent(Bool.self, forKey: .outlinePanel) ?? d.outlinePanel
    }
}

struct SplitState: Codable, Equatable {
    var panes: [[String]]
    var focused: Int
    var ratio: Double

    init(panes: [[String]] = [], focused: Int = 0, ratio: Double) {
        self.panes = panes
        self.focused = focused
        self.ratio = ratio
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        panes = try c.decodeIfPresent([[String]].self, forKey: .panes) ?? []
        focused = try c.decodeIfPresent(Int.self, forKey: .focused) ?? 0
        ratio = try c.decodeIfPresent(Double.self, forKey: .ratio) ?? 0.5
    }

    static func from(ratio: Double, panes: [Pane], focused: UUID, pathOf: (UUID) -> String?) -> SplitState {
        SplitState(
            panes: panes.map { pane in pane.tabs.compactMap(pathOf) },
            focused: panes.firstIndex { $0.id == focused } ?? 0,
            ratio: ratio
        )
    }

    func tabs(ids: [String: UUID], leftover: [UUID]) -> [[UUID]] {
        var seen = Set<String>()
        var tabs = panes.map { pane in
            pane.filter { seen.insert($0).inserted }.compactMap { ids[$0] }
        }
        if tabs.count < 2 {
            tabs += Array(repeating: [], count: 2 - tabs.count)
        }
        tabs = Array(tabs.prefix(2))
        let placed = Set(tabs.flatMap { $0 })
        tabs[0].append(contentsOf: leftover.filter { !placed.contains($0) })
        return tabs
    }
}

struct WorkspaceState: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var tabs: [TabState]
    var focusedPath: String?
    var layout: LayoutState
    var split: SplitState?
    var runConfigs: [RunConfig]
    var selectedTarget: String?

    init(
        version: Int = currentVersion,
        tabs: [TabState],
        focusedPath: String?,
        layout: LayoutState,
        split: SplitState? = nil,
        runConfigs: [RunConfig] = [],
        selectedTarget: String? = nil
    ) {
        self.version = version
        self.tabs = tabs
        self.focusedPath = focusedPath
        self.layout = layout
        self.split = split
        self.runConfigs = runConfigs
        self.selectedTarget = selectedTarget
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        tabs = try c.decodeIfPresent([TabState].self, forKey: .tabs) ?? []
        focusedPath = try c.decodeIfPresent(String.self, forKey: .focusedPath)
        layout = try c.decodeIfPresent(LayoutState.self, forKey: .layout) ?? .defaults
        split = try c.decodeIfPresent(SplitState.self, forKey: .split)
        runConfigs = try c.decodeIfPresent([RunConfig].self, forKey: .runConfigs) ?? []
        selectedTarget = try c.decodeIfPresent(String.self, forKey: .selectedTarget)
    }

    static func decode(_ data: Data) -> WorkspaceState? {
        guard let state = try? JSONDecoder().decode(WorkspaceState.self, from: data),
              state.version == currentVersion
        else {
            return nil
        }
        return state
    }
}
