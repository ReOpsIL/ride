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
    var terminalHeight: Double
    var testsHeight: Double
    var previewWidth: Double
    var showSidebar: Bool
    var showProblems: Bool
    var showRunOutput: Bool
    var showTerminal: Bool
    var showTests: Bool
    var showPreview: Bool
    var outlinePanel: Bool

    static let defaults = LayoutState(
        sidebarWidth: 230,
        outlineWidth: 220,
        problemsHeight: 180,
        runOutputHeight: 200,
        terminalHeight: 220,
        testsHeight: 200,
        previewWidth: 460,
        showSidebar: true,
        showProblems: false,
        showRunOutput: false,
        showTerminal: false,
        showTests: false,
        showPreview: false,
        outlinePanel: true
    )

    init(
        sidebarWidth: Double,
        outlineWidth: Double,
        problemsHeight: Double,
        runOutputHeight: Double,
        terminalHeight: Double = 220,
        testsHeight: Double = 200,
        previewWidth: Double,
        showSidebar: Bool,
        showProblems: Bool,
        showRunOutput: Bool,
        showTerminal: Bool = false,
        showTests: Bool = false,
        showPreview: Bool,
        outlinePanel: Bool
    ) {
        self.sidebarWidth = sidebarWidth
        self.outlineWidth = outlineWidth
        self.problemsHeight = problemsHeight
        self.runOutputHeight = runOutputHeight
        self.terminalHeight = terminalHeight
        self.testsHeight = testsHeight
        self.previewWidth = previewWidth
        self.showSidebar = showSidebar
        self.showProblems = showProblems
        self.showRunOutput = showRunOutput
        self.showTerminal = showTerminal
        self.showTests = showTests
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
        terminalHeight = try c.decodeIfPresent(Double.self, forKey: .terminalHeight) ?? d.terminalHeight
        testsHeight = try c.decodeIfPresent(Double.self, forKey: .testsHeight) ?? d.testsHeight
        previewWidth = try c.decodeIfPresent(Double.self, forKey: .previewWidth) ?? d.previewWidth
        showSidebar = try c.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? d.showSidebar
        showProblems = try c.decodeIfPresent(Bool.self, forKey: .showProblems) ?? d.showProblems
        showRunOutput = try c.decodeIfPresent(Bool.self, forKey: .showRunOutput) ?? d.showRunOutput
        showTerminal = try c.decodeIfPresent(Bool.self, forKey: .showTerminal) ?? d.showTerminal
        showTests = try c.decodeIfPresent(Bool.self, forKey: .showTests) ?? d.showTests
        showPreview = try c.decodeIfPresent(Bool.self, forKey: .showPreview) ?? d.showPreview
        outlinePanel = try c.decodeIfPresent(Bool.self, forKey: .outlinePanel) ?? d.outlinePanel
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
    var breakpoints: Breakpoints
    var watches: [String]

    init(
        version: Int = currentVersion,
        tabs: [TabState],
        focusedPath: String?,
        layout: LayoutState,
        split: SplitState? = nil,
        runConfigs: [RunConfig] = [],
        selectedTarget: String? = nil,
        breakpoints: Breakpoints = Breakpoints(),
        watches: [String] = []
    ) {
        self.version = version
        self.tabs = tabs
        self.focusedPath = focusedPath
        self.layout = layout
        self.split = split
        self.runConfigs = runConfigs
        self.selectedTarget = selectedTarget
        self.breakpoints = breakpoints
        self.watches = watches
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
        breakpoints = try c.decodeIfPresent(Breakpoints.self, forKey: .breakpoints) ?? Breakpoints()
        watches = try c.decodeIfPresent([String].self, forKey: .watches) ?? []
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
