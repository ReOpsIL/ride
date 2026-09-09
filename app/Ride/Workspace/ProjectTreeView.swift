import SwiftUI

struct TreeRow: View {
    @ObservedObject var node: FileNode
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let depth: Int
    @State private var hovering = false

    private var selected: Bool {
        state.selectedURL == node.url
    }

    private var expanded: Bool {
        state.expanded.contains(node.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if node.isDirectory, expanded {
                ForEach(node.children) { child in
                    TreeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var row: some View {
        let icon = FileIcon.spec(name: node.name, isDirectory: node.isDirectory, expanded: expanded, chrome: ts.chrome)
        return HStack(spacing: Tokens.Space.xs) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .animation(.easeOut(duration: 0.15), value: expanded)
                .frame(width: 12)
                .opacity(node.isDirectory ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
            Image(systemName: icon.symbol)
                .font(.system(size: Tokens.Size.iconM))
                .foregroundStyle(Color(icon.color))
                .frame(width: 16)
            Text(node.name)
                .font(Tokens.ui(12))
                .foregroundStyle(dimmed ? ts.ui.textTertiary : ts.ui.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Tokens.Space.xs)
            if dirty {
                Circle()
                    .fill(ts.ui.warning.opacity(node.isDirectory ? 0.5 : 1))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.leading, Tokens.Space.m + CGFloat(depth) * 12)
        .padding(.trailing, Tokens.Space.m)
        .frame(height: Tokens.Size.sidebarRow)
        .background(rowFill, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .simultaneousGesture(TapGesture(count: 1).onEnded(select))
        .simultaneousGesture(TapGesture(count: 2).onEnded(activate))
        .contextMenu { menu(for: node) }
    }

    private var dimmed: Bool {
        node.name.hasPrefix(".") || node.name == "target"
    }

    private var dirty: Bool {
        guard let root = state.workspaceRoot else {
            return false
        }
        let rel = WorkspaceFS.relativePath(root: root, file: node.url)
        return state.git.isDirty(relative: rel, isDirectory: node.isDirectory)
    }

    private var rowFill: Color {
        if selected {
            return ts.ui.bgSelection
        }
        if hovering {
            return ts.ui.bgHover
        }
        return .clear
    }

    private func select() {
        state.selectedURL = node.url
    }

    private func activate() {
        if node.isDirectory {
            toggle()
        } else {
            state.openFile(node.url)
        }
    }

    private func toggle() {
        if expanded {
            state.expanded.remove(node.url)
        } else {
            node.loadChildren()
            state.expanded.insert(node.url)
        }
    }

    @ViewBuilder
    private func menu(for node: FileNode) -> some View {
        let dir = WorkspaceFS.parentDir(for: node.url, isDirectory: node.isDirectory)
        Button("New File") { TreeActions.newFile(in: dir) }
        Button("New Folder") { TreeActions.newFolder(in: dir) }
        Button("Rename") { TreeActions.rename(node.url) }
        Button("Delete") { TreeActions.trash(node.url) }
        Button("Reveal in Finder") { TreeActions.reveal(node.url) }
    }
}
