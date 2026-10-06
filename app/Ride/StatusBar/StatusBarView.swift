import AppKit
import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            if let branch = state.git.branch {
                StatusSegment(icon: "arrow.triangle.branch", text: branch + GitSyncLabel.text(state.git.repo), help: "Git branch: show changes") {
                    state.toggleGit()
                }
            }
            StatusSegment(text: "Ln \(state.cursorLine), Col \(state.cursorColumn)", help: "Cursor position")
            StatusSegment(icon: pathIcon, text: state.relativePath, help: state.activeBuffer?.fileURL?.path ?? state.relativePath)
            if let error = state.formatError {
                StatusSegment(icon: "exclamationmark.circle", text: "\(formatter): \(error)", tint: ts.ui.error, help: error)
            }
            Spacer(minLength: 0)
            AIStatusView()
            CheckStatusView()
            IndexStatusView()
            if let buffer = state.activeBuffer {
                StatusSegment(text: buffer.lineEnding, help: "Line endings") {
                    LineEndingMenu.present(buffer: buffer, state: state)
                }
            }
            StatusSegment(text: IndentLabel.text(language: state.activeBuffer?.language, tabWidth: state.prefs.tabWidth), help: "Indentation")
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
        guard let buffer = state.activeBuffer else {
            return "doc"
        }
        return FileIcon.spec(for: buffer, chrome: ts.chrome).symbol
    }

    private var formatter: String {
        guard let buffer = state.activeBuffer, let engine = RideEngineClient.shared.engine else {
            return "format"
        }
        let name = engine.formatterName(path: buffer.fileURL?.path, text: buffer.text)
        return name.isEmpty ? "format" : name
    }
}
