import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject private var assistant = AIAssistant.shared
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
        .sheet(isPresented: $state.showToolsSheet) {
            ToolsInstallView().environmentObject(state)
        }
        .sheet(isPresented: $state.showNewProjectSheet) {
            NewProjectSheet().environmentObject(state)
        }
        .sheet(isPresented: $assistant.showPrompt) {
            AIAskSheet(assistant: assistant)
        }
        .sheet(isPresented: $state.showRunConfigSheet) {
            RunConfigSheet().environmentObject(state)
        }
        .sheet(isPresented: $state.showRenamePreview) {
            RenamePreviewSheet(
                model: state.renamePreview,
                root: state.workspaceRoot,
                onApply: { RenameController.shared.applyWorkspace() },
                onCancel: { state.showRenamePreview = false }
            )
        }
        .preferredColorScheme(state.isLightTheme ? .light : .dark)
        .onAppear {
            NSApp.appearance = NSAppearance(named: state.isLightTheme ? .aqua : .darkAqua)
            DemoLaunch.start(state: state)
        }
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
            if state.showGoToLine {
                GoToLineOverlay()
            }
            if state.showRecentFiles {
                RecentFilesOverlay()
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
