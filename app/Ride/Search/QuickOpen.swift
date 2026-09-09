import SwiftUI

struct QuickOpenOverlay: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    state.showQuickOpen = false
                }
            VStack(spacing: 0) {
                TextField("Open file", text: $state.quickQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(10)
                    .focused($focused)
                    .onSubmit {
                        state.confirmQuickOpen()
                    }
                Divider()
                if state.quickHits.isEmpty {
                    Text("No matching files")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeStore.shared.ui.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                } else {
                    List(state.quickHits, id: \.self, selection: $state.quickSelection) { url in
                        Text(label(url))
                            .font(.system(size: 12, design: .monospaced))
                            .tag(url)
                            .lineLimit(1)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: 280)
                }
            }
            .frame(width: 520)
            .background(ThemeStore.shared.ui.bgOverlay)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl).stroke(ThemeStore.shared.ui.border, lineWidth: 1))
            .shadow(radius: 16)
        }
        .onAppear {
            focused = true
            state.refreshQuickOpen()
        }
        .onChange(of: state.quickQuery) { _, _ in
            state.refreshQuickOpen()
        }
        .onExitCommand {
            state.showQuickOpen = false
        }
        .onKeyPress(.downArrow) {
            state.selectNextQuick()
            return .handled
        }
        .onKeyPress(.upArrow) {
            state.selectPreviousQuick()
            return .handled
        }
    }

    private func label(_ url: URL) -> String {
        guard let root = state.workspaceRoot else {
            return url.lastPathComponent
        }
        return WorkspaceFS.relativePath(root: root, file: url)
    }
}
