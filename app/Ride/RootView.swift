import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HSplitView {
            if state.showSidebar {
                SidebarView()
                    .frame(minWidth: 180, idealWidth: state.prefs.sidebarWidth, maxWidth: 420)
                    .background(SplitPositioner(position: state.prefs.sidebarWidth))
                    .reportSize(.width) { sidebarWidth.wrappedValue = $0 }
            }
            DetailColumn()
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ts.ui.bgBase)
        .background(WindowConfigurator())
        .toolbar {
            AppToolbar(state: state, hasWorkspace: state.workspaceRoot != nil, markdown: state.previewAvailable)
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .overlay {
            if state.showQuickOpen {
                QuickOpenOverlay()
            }
            if state.showSymbolInFile {
                SymbolInFileOverlay()
            }
            if state.showSymbolPicker {
                SymbolPickerOverlay(model: state.symbolPicker)
            }
            if state.showProjectFind {
                ProjectFindOverlay(model: state.projectFind)
            }
        }
    }
}

extension RootView {
    var sidebarWidth: Binding<Double> {
        Binding(
            get: { state.prefs.sidebarWidth },
            set: { value in state.saveLayout { $0.sidebarWidth = value } }
        )
    }
}

struct DetailColumn: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            TabStrip()
            if state.showFind {
                FindBar()
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
        }
    }

    private var outlineWidth: Binding<Double> {
        Binding(
            get: { state.prefs.outlineWidth },
            set: { value in state.saveLayout { $0.outlineWidth = value } }
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

    @ViewBuilder
    private var editor: some View {
        if let buffer = state.activeBuffer {
            EditorPane(document: buffer, state: state)
                .id(buffer.id)
        } else {
            WelcomeView()
        }
    }
}
