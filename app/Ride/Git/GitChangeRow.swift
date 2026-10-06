import SwiftUI

struct GitChangeRow: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let change: GitFileChange
    let side: GitDiffSide
    let selected: Bool
    @State private var hovering = false

    private var kind: GitChangeKind? {
        change.kind(on: side)
    }

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Button(action: toggleStage) {
                Image(systemName: side == .staged ? "checkmark.square.fill" : "square")
                    .font(.system(size: Tokens.Size.iconM))
                    .foregroundStyle(side == .staged ? ts.ui.accent : ts.ui.textTertiary)
            }
            .buttonStyle(.plain)
            .help(side == .staged ? "Unstage" : "Stage")
            Text(change.name)
                .font(Tokens.ui(12))
                .foregroundStyle(kind?.color(ts.ui) ?? ts.ui.textPrimary)
                .strikethrough(kind == .deleted)
                .lineLimit(1)
            Text(location)
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: Tokens.Space.xs)
            if let kind {
                Text(kind.letter)
                    .font(Tokens.mono(10, weight: .semibold))
                    .foregroundStyle(kind.color(ts.ui))
                    .help(kind.label)
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.sidebarRow)
        .background(rowFill, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .simultaneousGesture(TapGesture(count: 1).onEnded { state.selectGitChange(change, side: side) })
        .simultaneousGesture(TapGesture(count: 2).onEnded { state.openGitChange(change) })
        .contextMenu { menu }
    }

    private var location: String {
        let dir = change.directory
        guard let orig = change.origPath, side == .staged else {
            return dir
        }
        return "← \(orig)"
    }

    private var rowFill: Color {
        if selected {
            return ts.ui.bgSelection
        }
        return hovering ? ts.ui.bgHover : .clear
    }

    private func toggleStage() {
        if side == .staged {
            state.gitUnstage([change.path])
        } else {
            state.gitStage([change.path])
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Open File") { state.openGitChange(change) }
            .disabled(kind == .deleted)
        Button(side == .staged ? "Unstage" : "Stage", action: toggleStage)
        if side == .unstaged {
            Button("Discard Changes…") { state.gitDiscard([change]) }
        }
        Divider()
        Button("Copy Path") {
            if let url = state.git.map?.url(change.path) {
                TreeActions.copyPath(url, root: nil)
            }
        }
    }
}
