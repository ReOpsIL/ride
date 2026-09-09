import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            if let branch = state.git.branch {
                StatusSegment(icon: "arrow.triangle.branch", text: branch, help: "Git branch")
            }
            StatusSegment(icon: "text.cursor", text: "Ln \(state.cursorLine), Col \(state.cursorColumn)", help: "Cursor position")
            StatusSegment(icon: pathIcon, text: state.relativePath, help: state.activeBuffer?.fileURL?.path ?? state.relativePath)
            if let error = state.formatError {
                StatusSegment(icon: "exclamationmark.circle", text: "rustfmt: \(error)", tint: ts.ui.error, help: error)
            }
            Spacer(minLength: 0)
            CheckStatusView()
            IndexStatusView()
            StatusSegment(text: "Spaces: \(state.prefs.tabWidth)", help: "Indentation")
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: Tokens.Size.statusBar)
        .frame(maxWidth: .infinity)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .top) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }

    private var pathIcon: String {
        FileIcon.spec(name: state.activeBuffer?.displayName ?? "", isDirectory: false, chrome: ts.chrome).symbol
    }
}
