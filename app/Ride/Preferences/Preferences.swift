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
    var codeVision: Bool
    var diagnosticOverlay: DiagnosticOverlayMode
    var aiComplete: Bool
    var aiProvider: String
    var aiModel: String
    var aiContext: String
    var reportsAcknowledged: Double
    var lineEndings: String
    var semanticCompletion: Bool
    var assistant: AssistantPreferences

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
        codeVision: Bool = true,
        diagnosticOverlay: DiagnosticOverlayMode = .caret,
        aiComplete: Bool = false,
        aiProvider: String = "anthropic",
        aiModel: String = "",
        aiContext: String = "function",
        reportsAcknowledged: Double = 0,
        lineEndings: String = LineEndings.keep,
        semanticCompletion: Bool = true,
        assistant: AssistantPreferences = .defaults
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
        self.codeVision = codeVision
        self.diagnosticOverlay = diagnosticOverlay
        self.aiComplete = aiComplete
        self.aiProvider = aiProvider
        self.aiModel = aiModel
        self.aiContext = aiContext
        self.reportsAcknowledged = reportsAcknowledged
        self.lineEndings = lineEndings
        self.semanticCompletion = semanticCompletion
        self.assistant = assistant
    }

}
