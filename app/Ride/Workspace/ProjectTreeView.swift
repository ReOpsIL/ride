import SwiftUI

struct ProjectTreeView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.workspaceRoot?.lastPathComponent ?? "No Folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(state.rootNodes) { node in
                        TreeRow(node: node, depth: 0)
                    }
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TreeRow: View {
    @ObservedObject var node: FileNode
    @EnvironmentObject private var state: AppState
    let depth: Int
    @State private var hovering = false

    private var selected: Bool {
        state.selectedURL == node.url
    }

    private var expanded: Bool {
        state.expanded.contains(node.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            row
            if node.isDirectory, expanded {
                ForEach(node.children) { child in
                    TreeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var row: some View {
        HStack(spacing: 4) {
            if node.isDirectory {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
                    .frame(width: 12)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggle)
            } else {
                Color.clear.frame(width: 12, height: 1)
            }
            Label(node.name, systemImage: node.isDirectory ? "folder" : "doc")
                .lineLimit(1)
            if dirty {
                Circle()
                    .fill(Color.orange.opacity(node.isDirectory ? 0.45 : 0.95))
                    .frame(width: 6, height: 6)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .padding(.vertical, 3)
        .padding(.leading, 4 + CGFloat(depth) * 14)
        .padding(.trailing, 6)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(rowFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .simultaneousGesture(TapGesture(count: 1).onEnded(select))
        .simultaneousGesture(TapGesture(count: 2).onEnded(activate))
        .contextMenu { menu(for: node) }
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
            return Color.accentColor
        }
        if hovering {
            return Color.primary.opacity(0.08)
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
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            if expanded {
                state.expanded.remove(node.url)
            } else {
                node.loadChildren()
                state.expanded.insert(node.url)
            }
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
