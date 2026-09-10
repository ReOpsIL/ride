import SwiftUI

struct RecentFilesOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        let hits = state.recentHits
        PickerCard(
            query: $state.recentQuery,
            placeholder: "Recent files",
            trailing: hits.isEmpty ? nil : Plural.count(hits.count, "file"),
            onSubmit: { state.confirmRecentFile() },
            onDismiss: { state.showRecentFiles = false }
        ) {
            if hits.isEmpty {
                PickerEmpty(text: state.recentFiles.isEmpty ? "No files opened yet" : "No matching files")
            } else {
                PickerList(count: hits.count, selected: hits.firstIndex { $0 == state.recentSelection }) { i in
                    let url = hits[i]
                    let spec = FileIcon.spec(name: url.lastPathComponent, isDirectory: false, chrome: ts.chrome)
                    PickerRow(
                        title: url.lastPathComponent,
                        query: state.recentQuery,
                        subtitle: state.workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: url.deletingLastPathComponent()) } ?? "",
                        selected: state.recentSelection == url,
                        action: {
                            state.recentSelection = url
                            state.confirmRecentFile()
                        }
                    ) {
                        Image(systemName: spec.symbol)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(spec.color))
                    }
                }
            }
        }
        .onChange(of: state.recentQuery) { _, _ in state.recentSelection = state.recentHits.first }
        .onKeyPress(.downArrow) {
            state.moveRecentSelection(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            state.moveRecentSelection(-1)
            return .handled
        }
    }
}
