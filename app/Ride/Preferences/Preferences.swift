import Foundation

struct Preferences: Codable, Equatable {
    var theme: String
    var fontSize: Int
    var tabWidth: Int
    var autoSave: Bool
    var completions: Bool
    var cheatSheet: Bool
    var softWrap: Bool
    var askMissingTools: Bool
    var outlinePanel: Bool
    var visibleWhitespace: Bool
    var showHidden: Bool
    var checkOnSave: Bool
    var useClippy: Bool
    var formatOnSave: Bool
    var indentGuides: Bool
    var lineNumbers: Bool
    var sidebarWidth: Double
    var outlineWidth: Double
    var hierarchyWidth: Double
    var problemsHeight: Double
    var runOutputHeight: Double
    var terminalHeight: Double
    var testsHeight: Double
    var debugHeight: Double
    var previewWidth: Double
    var signatureHelp: Bool
    var hoverDocs: Bool
    var codeVision: Bool
    var aiComplete: Bool
    var aiProvider: String
    var aiModel: String
    var aiContext: String
    var reportsAcknowledged: Double
    var lineEndings: String

    static let fontSizes = 10...24

    static let defaults = Preferences(
        theme: "dark",
        fontSize: 13,
        tabWidth: 4,
        autoSave: true,
        completions: true,
        outlinePanel: true,
        visibleWhitespace: false,
        showHidden: false,
        checkOnSave: true,
        useClippy: false,
        formatOnSave: false,
        indentGuides: true,
        cheatSheet: true,
        softWrap: true,
        askMissingTools: true
    )

    init(
        theme: String,
        fontSize: Int,
        tabWidth: Int,
        autoSave: Bool,
        completions: Bool,
        outlinePanel: Bool,
        visibleWhitespace: Bool,
        showHidden: Bool,
        checkOnSave: Bool = true,
        useClippy: Bool = false,
        formatOnSave: Bool = false,
        indentGuides: Bool = true,
        lineNumbers: Bool = true,
        sidebarWidth: Double = LayoutState.defaults.sidebarWidth,
        outlineWidth: Double = LayoutState.defaults.outlineWidth,
        hierarchyWidth: Double = LayoutState.defaults.hierarchyWidth,
        problemsHeight: Double = LayoutState.defaults.problemsHeight,
        runOutputHeight: Double = LayoutState.defaults.runOutputHeight,
        terminalHeight: Double = LayoutState.defaults.terminalHeight,
        testsHeight: Double = LayoutState.defaults.testsHeight,
        debugHeight: Double = LayoutState.defaults.debugHeight,
        previewWidth: Double = LayoutState.defaults.previewWidth,
        cheatSheet: Bool = true,
        softWrap: Bool = true,
        askMissingTools: Bool = true,
        signatureHelp: Bool = true,
        hoverDocs: Bool = true,
        codeVision: Bool = true,
        aiComplete: Bool = false,
        aiProvider: String = "anthropic",
        aiModel: String = "",
        aiContext: String = "function",
        reportsAcknowledged: Double = 0,
        lineEndings: String = LineEndings.keep
    ) {
        self.theme = theme
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.autoSave = autoSave
        self.completions = completions
        self.outlinePanel = outlinePanel
        self.visibleWhitespace = visibleWhitespace
        self.showHidden = showHidden
        self.checkOnSave = checkOnSave
        self.useClippy = useClippy
        self.formatOnSave = formatOnSave
        self.indentGuides = indentGuides
        self.lineNumbers = lineNumbers
        self.sidebarWidth = sidebarWidth
        self.outlineWidth = outlineWidth
        self.hierarchyWidth = hierarchyWidth
        self.problemsHeight = problemsHeight
        self.runOutputHeight = runOutputHeight
        self.terminalHeight = terminalHeight
        self.testsHeight = testsHeight
        self.debugHeight = debugHeight
        self.previewWidth = previewWidth
        self.cheatSheet = cheatSheet
        self.softWrap = softWrap
        self.askMissingTools = askMissingTools
        self.signatureHelp = signatureHelp
        self.hoverDocs = hoverDocs
        self.codeVision = codeVision
        self.aiComplete = aiComplete
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiContext = aiContext
        self.reportsAcknowledged = reportsAcknowledged
        self.lineEndings = lineEndings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences.defaults
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? d.theme
        fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize) ?? d.fontSize
        tabWidth = try c.decodeIfPresent(Int.self, forKey: .tabWidth) ?? d.tabWidth
        autoSave = try c.decodeIfPresent(Bool.self, forKey: .autoSave) ?? d.autoSave
        completions = try c.decodeIfPresent(Bool.self, forKey: .completions) ?? d.completions
        cheatSheet = try c.decodeIfPresent(Bool.self, forKey: .cheatSheet) ?? d.cheatSheet
        softWrap = try c.decodeIfPresent(Bool.self, forKey: .softWrap) ?? d.softWrap
        askMissingTools = try c.decodeIfPresent(Bool.self, forKey: .askMissingTools) ?? d.askMissingTools
        outlinePanel = try c.decodeIfPresent(Bool.self, forKey: .outlinePanel) ?? d.outlinePanel
        visibleWhitespace = try c.decodeIfPresent(Bool.self, forKey: .visibleWhitespace) ?? d.visibleWhitespace
        showHidden = try c.decodeIfPresent(Bool.self, forKey: .showHidden) ?? d.showHidden
        checkOnSave = try c.decodeIfPresent(Bool.self, forKey: .checkOnSave) ?? d.checkOnSave
        useClippy = try c.decodeIfPresent(Bool.self, forKey: .useClippy) ?? d.useClippy
        formatOnSave = try c.decodeIfPresent(Bool.self, forKey: .formatOnSave) ?? d.formatOnSave
        indentGuides = try c.decodeIfPresent(Bool.self, forKey: .indentGuides) ?? d.indentGuides
        lineNumbers = try c.decodeIfPresent(Bool.self, forKey: .lineNumbers) ?? d.lineNumbers
        sidebarWidth = try c.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? d.sidebarWidth
        outlineWidth = try c.decodeIfPresent(Double.self, forKey: .outlineWidth) ?? d.outlineWidth
        hierarchyWidth = try c.decodeIfPresent(Double.self, forKey: .hierarchyWidth) ?? d.hierarchyWidth
        problemsHeight = try c.decodeIfPresent(Double.self, forKey: .problemsHeight) ?? d.problemsHeight
        runOutputHeight = try c.decodeIfPresent(Double.self, forKey: .runOutputHeight) ?? d.runOutputHeight
        terminalHeight = try c.decodeIfPresent(Double.self, forKey: .terminalHeight) ?? d.terminalHeight
        testsHeight = try c.decodeIfPresent(Double.self, forKey: .testsHeight) ?? d.testsHeight
        debugHeight = try c.decodeIfPresent(Double.self, forKey: .debugHeight) ?? d.debugHeight
        previewWidth = try c.decodeIfPresent(Double.self, forKey: .previewWidth) ?? d.previewWidth
        signatureHelp = try c.decodeIfPresent(Bool.self, forKey: .signatureHelp) ?? d.signatureHelp
        hoverDocs = try c.decodeIfPresent(Bool.self, forKey: .hoverDocs) ?? d.hoverDocs
        codeVision = try c.decodeIfPresent(Bool.self, forKey: .codeVision) ?? d.codeVision
        aiComplete = try c.decodeIfPresent(Bool.self, forKey: .aiComplete) ?? d.aiComplete
        aiProvider = try c.decodeIfPresent(String.self, forKey: .aiProvider) ?? d.aiProvider
        aiModel = try c.decodeIfPresent(String.self, forKey: .aiModel) ?? d.aiModel
        aiContext = try c.decodeIfPresent(String.self, forKey: .aiContext) ?? d.aiContext
        reportsAcknowledged = try c.decodeIfPresent(Double.self, forKey: .reportsAcknowledged) ?? d.reportsAcknowledged
        lineEndings = try c.decodeIfPresent(String.self, forKey: .lineEndings) ?? d.lineEndings
    }

    var clamped: Preferences {
        var next = self
        next.fontSize = min(Self.fontSizes.upperBound, max(Self.fontSizes.lowerBound, fontSize))
        next.tabWidth = min(8, max(2, tabWidth))
        next.sidebarWidth = min(420, max(180, sidebarWidth))
        next.outlineWidth = min(420, max(160, outlineWidth))
        next.hierarchyWidth = min(420, max(160, hierarchyWidth))
        next.problemsHeight = min(480, max(80, problemsHeight))
        next.runOutputHeight = min(480, max(80, runOutputHeight))
        next.terminalHeight = min(480, max(80, terminalHeight))
        next.testsHeight = min(480, max(80, testsHeight))
        next.debugHeight = min(600, max(320, debugHeight))
        next.previewWidth = min(900, max(260, previewWidth))
        next.reportsAcknowledged = max(0, reportsAcknowledged)
        if next.theme != "light" {
            next.theme = "dark"
        }
        if next.lineEndings != LineEndings.lf {
            next.lineEndings = LineEndings.keep
        }
        return next
    }
}
