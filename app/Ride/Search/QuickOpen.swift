import SwiftUI

struct QuickOpenOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        PickerCard(
            query: $state.quickQuery,
            placeholder: "Open file by name",
            trailing: state.quickHits.isEmpty ? nil : Plural.count(state.quickHits.count, "file"),
            onSubmit: { state.confirmQuickOpen() },
            onDismiss: { state.showQuickOpen = false }
        ) {
            if state.quickHits.isEmpty {
                PickerEmpty(text: state.quickQuery.isEmpty ? "Type a file name" : "No matching files")
            } else {
                PickerList(count: state.quickHits.count, selected: selectedIndex) { i in
                    let url = state.quickHits[i]
                    let spec = FileIcon.spec(name: url.lastPathComponent, isDirectory: false, chrome: ts.chrome)
                    PickerRow(
                        title: url.lastPathComponent,
                        query: state.quickQuery,
                        subtitle: directory(url),
                        selected: state.quickSelection == url,
                        action: {
                            state.quickSelection = url
                            state.confirmQuickOpen()
                        }
                    ) {
                        Image(systemName: spec.symbol)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(spec.color))
                    }
                }
            }
        }
        .onAppear { state.refreshQuickOpen() }
        .onChange(of: state.quickQuery) { _, _ in state.refreshQuickOpen() }
        .onKeyPress(.downArrow) {
            state.selectNextQuick()
            return .handled
        }
        .onKeyPress(.upArrow) {
            state.selectPreviousQuick()
            return .handled
        }
    }

    private var selectedIndex: Int? {
        state.quickSelection.flatMap { state.quickHits.firstIndex(of: $0) }
    }

    private func directory(_ url: URL) -> String {
        guard let root = state.workspaceRoot else {
            return ""
        }
        let rel = WorkspaceFS.relativePath(root: root, file: url.deletingLastPathComponent())
        return rel == "." ? "" : rel
    }
}
