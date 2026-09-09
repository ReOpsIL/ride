import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ts.ui.border.frame(height: Tokens.Size.hairline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(state.rootNodes) { node in
                        TreeRow(node: node, depth: 0)
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ts.ui.bgBase)
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "folder.fill")
                .font(.system(size: Tokens.Size.iconS, weight: .semibold))
                .foregroundStyle(ts.ui.accent)
            Text(state.workspaceRoot?.lastPathComponent ?? "No Folder")
                .font(Tokens.ui(12, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let root = state.workspaceRoot {
                IconButton(symbol: "doc.badge.plus", help: "New File") {
                    TreeActions.newFile(in: root)
                }
                IconButton(symbol: "arrow.down.right.and.arrow.up.left", help: "Collapse All") {
                    state.expanded = []
                }
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.panelHeader)
        .background(ts.ui.bgBase)
        .overlay(alignment: .top) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }
}
