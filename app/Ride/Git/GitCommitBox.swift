import SwiftUI

struct GitCommitBox: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let repo: GitRepoStatus
    @ObservedObject var model: GitChangesModel
    @FocusState private var editing: Bool

    private var hasStaged: Bool {
        repo.changes.contains { $0.staged != nil }
    }

    private var canCommit: Bool {
        guard !model.isBusy else {
            return false
        }
        if model.amend {
            return true
        }
        return !repo.changes.isEmpty && !model.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var commitTitle: String {
        if model.amend {
            return "Amend"
        }
        return hasStaged ? "Commit" : "Commit All"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            GrowingTextEditor(
                text: $model.message,
                placeholder: "Commit message",
                lines: 2...8,
                focus: $editing
            )
            .padding(Tokens.Space.xs)
            .background(ts.ui.bgRaised, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.s).stroke(ts.ui.border))
            HStack(spacing: Tokens.Space.m) {
                Toggle("Amend", isOn: $model.amend)
                    .toggleStyle(.checkbox)
                    .font(Tokens.ui(11))
                    .onChange(of: model.amend) { _, _ in state.gitAmendChanged() }
                Spacer(minLength: 0)
                Button(commitTitle) { state.gitCommit(push: false) }
                    .disabled(!canCommit)
                    .help(Shortcuts.help(commitTitle, "Git › Commit…"))
                Button("\(commitTitle) and Push") { state.gitCommit(push: true) }
                    .disabled(!canCommit)
            }
            .controlSize(.small)
        }
        .padding(Tokens.Space.m)
        .onAppear(perform: takeFocus)
        .onChange(of: model.focusMessage) { _, _ in takeFocus() }
    }

    private func takeFocus() {
        guard model.focusMessage else {
            return
        }
        model.focusMessage = false
        editing = true
    }
}
