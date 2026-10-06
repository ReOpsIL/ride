import SwiftUI

struct GitChangeList: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let repo: GitRepoStatus
    @ObservedObject var model: GitChangesModel

    private var staged: [GitFileChange] {
        repo.changes.filter { $0.staged != nil }
    }

    private var unstaged: [GitFileChange] {
        repo.changes.filter { $0.unstaged != nil }
    }

    var body: some View {
        if repo.changes.isEmpty {
            Text("No changes")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !staged.isEmpty {
                        section("Staged", count: staged.count, action: "Unstage All") {
                            state.gitUnstage(staged.map(\.path))
                        }
                        rows(staged, side: .staged)
                    }
                    if !unstaged.isEmpty {
                        section("Changes", count: unstaged.count, action: "Stage All") {
                            state.gitStage(unstaged.map(\.path))
                        }
                        rows(unstaged, side: .unstaged)
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }

    private func section(_ title: String, count: Int, action: String, run: @escaping () -> Void) -> some View {
        HStack(spacing: Tokens.Space.s) {
            Text(title.uppercased())
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.textSecondary)
            Text("\(count)")
                .font(Tokens.ui(10))
                .foregroundStyle(ts.ui.textTertiary)
            Spacer(minLength: 0)
            Button(action, action: run)
                .buttonStyle(.plain)
                .font(Tokens.ui(10))
                .foregroundStyle(ts.ui.accent)
                .disabled(model.isBusy)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.top, Tokens.Space.s)
        .padding(.bottom, Tokens.Space.xxs)
    }

    private func rows(_ changes: [GitFileChange], side: GitDiffSide) -> some View {
        ForEach(changes, id: \.path) { change in
            GitChangeRow(
                change: change,
                side: side,
                selected: model.selection == GitSelection(path: change.path, side: side)
            )
        }
    }
}
