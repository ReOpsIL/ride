import Foundation

struct LayoutState: Codable, Equatable {
    var sidebarWidth: Double
    var outlineWidth: Double
    var hierarchyWidth: Double
    var problemsHeight: Double
    var runOutputHeight: Double
    var terminalHeight: Double
    var testsHeight: Double
    var debugHeight: Double
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
        hierarchyWidth: 220,
        problemsHeight: 180,
        runOutputHeight: 200,
        terminalHeight: 220,
        testsHeight: 200,
        debugHeight: 320,
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
        hierarchyWidth: Double = LayoutState.defaults.hierarchyWidth,
        problemsHeight: Double,
        runOutputHeight: Double,
        terminalHeight: Double = LayoutState.defaults.terminalHeight,
        testsHeight: Double = LayoutState.defaults.testsHeight,
        debugHeight: Double = LayoutState.defaults.debugHeight,
        previewWidth: Double,
        showSidebar: Bool,
        showProblems: Bool,
        showRunOutput: Bool,
        showTerminal: Bool = LayoutState.defaults.showTerminal,
        showTests: Bool = LayoutState.defaults.showTests,
        showPreview: Bool,
        outlinePanel: Bool
    ) {
        self.sidebarWidth = sidebarWidth
        self.outlineWidth = outlineWidth
        self.hierarchyWidth = hierarchyWidth
        self.problemsHeight = problemsHeight
        self.runOutputHeight = runOutputHeight
        self.terminalHeight = terminalHeight
        self.testsHeight = testsHeight
        self.debugHeight = debugHeight
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
        hierarchyWidth = try c.decodeIfPresent(Double.self, forKey: .hierarchyWidth) ?? d.hierarchyWidth
        problemsHeight = try c.decodeIfPresent(Double.self, forKey: .problemsHeight) ?? d.problemsHeight
        runOutputHeight = try c.decodeIfPresent(Double.self, forKey: .runOutputHeight) ?? d.runOutputHeight
        terminalHeight = try c.decodeIfPresent(Double.self, forKey: .terminalHeight) ?? d.terminalHeight
        testsHeight = try c.decodeIfPresent(Double.self, forKey: .testsHeight) ?? d.testsHeight
        debugHeight = try c.decodeIfPresent(Double.self, forKey: .debugHeight) ?? d.debugHeight
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
