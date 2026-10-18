import Foundation

extension Preferences {
    enum CodingKeys: String, CodingKey {
        case theme
        case fontSize
        case tabWidth
        case autoSave
        case completions
        case cheatSheet
        case softWrap
        case askMissingTools
        case outlinePanel
        case visibleWhitespace
        case showHidden
        case checkOnSave
        case useClippy
        case formatOnSave
        case indentGuides
        case lineNumbers
        case sidebarWidth
        case outlineWidth
        case hierarchyWidth
        case problemsHeight
        case runOutputHeight
        case terminalHeight
        case testsHeight
        case debugHeight
        case previewWidth
        case signatureHelp
        case hoverDocs
        case codeVision
        case diagnosticOverlay
        case aiComplete
        case aiProvider
        case aiModel
        case aiContext
        case reportsAcknowledged
        case lineEndings
        case semanticCompletion
        case assistant
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
        diagnosticOverlay = try c.decodeIfPresent(DiagnosticOverlayMode.self, forKey: .diagnosticOverlay) ?? d.diagnosticOverlay
        aiComplete = try c.decodeIfPresent(Bool.self, forKey: .aiComplete) ?? d.aiComplete
        aiProvider = try c.decodeIfPresent(String.self, forKey: .aiProvider) ?? d.aiProvider
        aiModel = try c.decodeIfPresent(String.self, forKey: .aiModel) ?? d.aiModel
        aiContext = try c.decodeIfPresent(String.self, forKey: .aiContext) ?? d.aiContext
        reportsAcknowledged = try c.decodeIfPresent(Double.self, forKey: .reportsAcknowledged) ?? d.reportsAcknowledged
        lineEndings = try c.decodeIfPresent(String.self, forKey: .lineEndings) ?? d.lineEndings
        semanticCompletion = try c.decodeIfPresent(Bool.self, forKey: .semanticCompletion) ?? d.semanticCompletion
        assistant = try c.decodeIfPresent(AssistantPreferences.self, forKey: .assistant) ?? d.assistant
    }
}
