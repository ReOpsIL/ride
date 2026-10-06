import SwiftUI

struct GitDiffView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let diff: GitFileDiff?
    let error: String?
    let hasSelection: Bool

    var body: some View {
        if let error {
            placeholder(error)
        } else if let diff, diff.binary {
            placeholder("Binary file \(diff.path)")
        } else if let diff, !diff.hunks.isEmpty {
            GitDiffScrollView(diff: diff, fontSize: state.prefs.fontSize)
        } else {
            placeholder(hasSelection && diff != nil ? "No differences" : "Select a file to see its diff")
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Tokens.Space.l)
    }
}
