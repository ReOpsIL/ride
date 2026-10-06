import SwiftUI

struct GitPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var status: GitStatusService
    @ObservedObject var model: GitChangesModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "arrow.triangle.branch", title: "Changes", badges: badges) {
                if status.repo != nil {
                    GitBranchMenu(status: status, model: model)
                    IconButton(symbol: "arrow.down.circle", help: "Pull") {
                        state.gitPull()
                    }
                    .disabled(model.isBusy)
                    IconButton(symbol: "arrow.up.circle", help: Shortcuts.help("Push", "Git › Push")) {
                        state.gitPush()
                    }
                    .disabled(model.isBusy)
                }
                IconButton(symbol: "arrow.clockwise", help: "Refresh") {
                    state.refreshGit()
                }
                IconButton(symbol: "xmark", help: "Hide Changes", size: 9) {
                    state.showGit = false
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        guard let repo = status.repo else {
            return []
        }
        var out: [PanelBadge] = []
        if repo.ahead > 0 {
            out.append(PanelBadge(id: "ahead", text: "↑\(repo.ahead)", tint: ts.ui.accent))
        }
        if repo.behind > 0 {
            out.append(PanelBadge(id: "behind", text: "↓\(repo.behind)", tint: ts.ui.warning))
        }
        if let busy = model.busy {
            out.append(PanelBadge(id: "busy", text: busy, tint: ts.ui.accent))
        } else if !repo.changes.isEmpty {
            out.append(PanelBadge(id: "count", text: Plural.count(repo.changes.count, "change"), tint: nil))
        }
        return out
    }

    @ViewBuilder
    private var content: some View {
        if let repo = status.repo {
            HSplitView {
                VStack(spacing: 0) {
                    GitChangeList(repo: repo, model: model)
                    ts.ui.border.frame(height: Tokens.Size.hairline)
                    GitCommitBox(repo: repo, model: model)
                }
                .frame(minWidth: 240, idealWidth: 340, maxWidth: .infinity)
                GitDiffView(diff: model.diff, error: model.diffError, hasSelection: model.selection != nil)
                    .frame(minWidth: 240, maxWidth: .infinity)
            }
        } else {
            Text(state.workspaceRoot == nil ? "Open a folder to see its changes" : "This folder is not inside a git repository")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        }
    }
}
