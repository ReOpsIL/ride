import SwiftUI

struct GitPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var status: GitStatusService
    @ObservedObject var model: GitChangesModel
    @ObservedObject var review: ReviewModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "arrow.triangle.branch", title: "Changes", badges: badges) {
                Picker("", selection: segment) {
                    Text("Files").tag(ReviewSegment.files)
                    Text("Symbols").tag(ReviewSegment.symbols)
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(maxWidth: 132)
                .labelsHidden()
                .accessibilityLabel("Changes segment")
                if status.repo != nil, review.segment == .files {
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
        .onChange(of: review.segment) { _, segment in
            if segment == .symbols {
                review.reload(root: status.root)
            }
        }
    }

    private var segment: Binding<ReviewSegment> {
        Binding(get: { review.segment }, set: { review.segment = $0 })
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
        if review.segment == .symbols, let upstream = review.inbox?.upstream, !upstream.isEmpty {
            out.append(PanelBadge(id: "base", text: "against \(upstream)", tint: nil))
        } else if let busy = model.busy {
            out.append(PanelBadge(id: "busy", text: busy, tint: ts.ui.accent))
        } else if !repo.changes.isEmpty {
            out.append(PanelBadge(id: "count", text: Plural.count(repo.changes.count, "change"), tint: nil))
        }
        return out
    }

    @ViewBuilder
    private var content: some View {
        if review.segment == .symbols {
            if status.repo == nil {
                missing
            } else {
                HSplitView {
                    ReviewList(review: review)
                        .frame(minWidth: 280, idealWidth: 460, maxWidth: .infinity)
                    ReviewDossierPanel(review: review)
                        .frame(minWidth: 240, idealWidth: 320, maxWidth: 420)
                }
            }
        } else if let repo = status.repo {
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
            missing
        }
    }

    private var missing: some View {
        Text(state.workspaceRoot == nil ? "Open a folder to see its changes" : "This folder is not inside a git repository")
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Tokens.Space.l)
    }
}
