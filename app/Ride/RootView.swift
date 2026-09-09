import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HSplitView {
            if state.showSidebar {
                SidebarView()
                    .frame(width: state.prefs.sidebarWidth)
            }
            DetailColumn()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    if state.showSidebar {
                        SplitHandle(axis: .horizontal, value: sidebarWidth, range: 180...420)
                    }
                }
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
                    .frame(maxHeight: .infinity)
                if state.showProblems {
                    ProblemsPanel()
                        .frame(height: state.prefs.problemsHeight)
                        .overlay(alignment: .top) {
                            SplitHandle(axis: .vertical, value: problemsHeight, range: 80...480, inverted: true)
                        }
                }
            }
            StatusBarView()
        }
        .background(ts.ui.bgBase)
    }

    private var editorRow: some View {
        HSplitView {
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if state.previewVisible {
                PreviewPane()
                    .frame(width: state.prefs.previewWidth)
                    .overlay(alignment: .leading) {
                        SplitHandle(axis: .horizontal, value: previewWidth, range: 260...900, inverted: true)
                    }
            }
            if state.prefs.outlinePanel {
                FileOutlineView()
                    .frame(width: state.prefs.outlineWidth)
                    .overlay(alignment: .leading) {
                        SplitHandle(axis: .horizontal, value: outlineWidth, range: 160...420, inverted: true)
                    }
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
