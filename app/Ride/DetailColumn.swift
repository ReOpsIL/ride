import SwiftUI

struct DetailColumn: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject private var debugPanel = DebugPanelModel.shared
    @ObservedObject private var assistant = AIAssistant.shared

    var body: some View {
        VStack(spacing: 0) {
            PaneTabStrips()
            if let notice = state.notice {
                NoticeBar(text: notice, actionTitle: state.noticeAction?.title, action: state.noticeAction?.run) {
                    state.dismissNotice()
                }
            }
            VSplitView {
                editorRow
                    .frame(minHeight: 160, maxHeight: .infinity)
                if state.showProblems {
                    ProblemsPanel()
                        .frame(minHeight: 80, idealHeight: state.prefs.problemsHeight, maxHeight: 480)
                        .background(SplitPositioner(position: state.prefs.problemsHeight, fromEnd: true))
                        .reportSize(.height) { problemsHeight.wrappedValue = $0 }
                }
                if state.showTerminal {
                    TerminalPanel(store: state.terminals)
                        .frame(minHeight: 80, idealHeight: state.prefs.terminalHeight, maxHeight: 480)
                        .background(SplitPositioner(position: state.prefs.terminalHeight, fromEnd: true))
                        .reportSize(.height) { terminalHeight.wrappedValue = $0 }
                }
                if state.showTests {
                    TestsPanel(store: state.testRun)
                        .frame(minHeight: 80, idealHeight: state.prefs.testsHeight, maxHeight: 480)
                        .background(SplitPositioner(position: state.prefs.testsHeight, fromEnd: true))
                        .reportSize(.height) { testsHeight.wrappedValue = $0 }
                }
                if state.showUsages {
                    UsagesPanel(model: state.usages)
                        .frame(minHeight: 80, idealHeight: 220, maxHeight: 480)
                }
                if assistant.showPanel {
                    AIAnswerPanel(assistant: assistant)
                        .frame(minHeight: 80, idealHeight: 260, maxHeight: 600)
                }
                if debugPanel.visible {
                    DebugPanel(model: debugPanel)
                        .frame(minHeight: 320, idealHeight: state.prefs.debugHeight, maxHeight: 600)
                        .background(SplitPositioner(position: state.prefs.debugHeight, fromEnd: true))
                        .reportSize(.height) { debugHeight.wrappedValue = $0 }
                }
                if state.showRunOutput {
                    RunOutputPanel(output: state.runOutput)
                        .frame(minHeight: 80, idealHeight: state.prefs.runOutputHeight, maxHeight: 480)
                        .background(SplitPositioner(position: state.prefs.runOutputHeight, fromEnd: true))
                        .reportSize(.height) { runOutputHeight.wrappedValue = $0 }
                }
            }

            StatusBarView()
        }
        .background(ts.ui.bgBase)
    }

    private var editorRow: some View {
        HStack(spacing: 0) {
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if state.previewVisible {
                SplitHandle(axis: .horizontal, value: previewWidth, range: 260...900, inverted: true)
                PreviewPane()
                    .frame(width: state.prefs.previewWidth)
            }
            if state.prefs.outlinePanel {
                SplitHandle(axis: .horizontal, value: outlineWidth, range: 160...420, inverted: true)
                FileOutlineView()
                    .frame(width: state.prefs.outlineWidth)
            }
            if state.showHierarchy {
                SplitHandle(axis: .horizontal, value: hierarchyWidth, range: 160...420, inverted: true)
                HierarchyPanel()
                    .frame(width: state.prefs.hierarchyWidth)
            }
        }
    }

    private var outlineWidth: Binding<Double> {
        Binding(
            get: { state.prefs.outlineWidth },
            set: { value in state.saveLayout { $0.outlineWidth = value } }
        )
    }

    private var hierarchyWidth: Binding<Double> {
        Binding(
            get: { state.prefs.hierarchyWidth },
            set: { value in state.saveLayout { $0.hierarchyWidth = value } }
        )
    }

    private var previewWidth: Binding<Double> {
        Binding(
            get: { state.prefs.previewWidth },
            set: { value in state.saveLayout { $0.previewWidth = value } }
        )
    }

    private var problemsHeight: Binding<Double> {
        Binding(
            get: { state.prefs.problemsHeight },
            set: { value in state.saveLayout { $0.problemsHeight = value } }
        )
    }

    private var testsHeight: Binding<Double> {
        Binding(
            get: { state.prefs.testsHeight },
            set: { value in state.saveLayout { $0.testsHeight = value } }
        )
    }

    private var terminalHeight: Binding<Double> {
        Binding(
            get: { state.prefs.terminalHeight },
            set: { value in state.saveLayout { $0.terminalHeight = value } }
        )
    }

    private var debugHeight: Binding<Double> {
        Binding(
            get: { state.prefs.debugHeight },
            set: { value in state.saveLayout { $0.debugHeight = value } }
        )
    }

    private var runOutputHeight: Binding<Double> {
        Binding(
            get: { state.prefs.runOutputHeight },
            set: { value in state.saveLayout { $0.runOutputHeight = value } }
        )
    }

    private var editor: some View {
        EditorSplit()
    }
}
