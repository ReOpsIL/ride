import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            ProjectTreeView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                TabStrip()
                if state.showFind {
                    FindBar()
                }
                HStack(spacing: 0) {
                    if let buffer = state.activeBuffer {
                        EditorPane(document: buffer, state: state)
                            .id(buffer.id)
                    } else {
                        EditorPlaceholder()
                    }
                    if state.prefs.outlinePanel {
                        FileOutlineView()
                    }
                }
                if state.showProblems {
                    ProblemsPanel()
                }
                StatusBarView()
            }
        }
        .navigationTitle(state.windowTitle)
        .navigationSplitViewStyle(.balanced)
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

struct EditorPlaceholder: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            Text(state.workspaceRoot == nil ? "Open a folder to start" : "No file open")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
