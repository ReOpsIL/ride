import AppKit
import SwiftUI

struct ProjectTreeView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(state.rootNodes) { node in
                    TreeRow(node: node, depth: 0)
                }
            }
            .padding(.vertical, Tokens.Space.xs)
            TreeKeyHost()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
    }
}

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
        TreeKeyFocus.select(node.url)
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
        Button("Rename") { TreeActions.run(.rename, url: node.url) }
        Button("Duplicate") { TreeActions.duplicate(node.url) }
        Button("Delete") { TreeActions.run(.trash, url: node.url) }
        Divider()
        Button("Copy Path") { TreeActions.copyPath(node.url, root: nil) }
        Button("Copy Relative Path") { TreeActions.copyPath(node.url, root: state.workspaceRoot) }
        Button("Reveal in Finder") { TreeActions.reveal(node.url) }
        Button("Open in Terminal") { TreeActions.openInTerminal(node.url, isDirectory: node.isDirectory) }
    }
}

enum TreeKeyFocus {
    static weak var view: TreeKeyView?
    static var url: URL?

    static func select(_ url: URL) {
        self.url = url
        DispatchQueue.main.async {
            view?.window?.makeFirstResponder(view)
        }
    }
}

struct TreeKeyHost: NSViewRepresentable {
    func makeNSView(context: Context) -> TreeKeyView {
        let view = TreeKeyView()
        TreeKeyFocus.view = view
        return view
    }

    func updateNSView(_ view: TreeKeyView, context: Context) {
        TreeKeyFocus.view = view
    }
}

final class TreeKeyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            TreeKeyFocus.view = self
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func keyDown(with event: NSEvent) {
        if TreeActions.handleKey(keyCode: event.keyCode, url: TreeKeyFocus.url) {
            return
        }
        super.keyDown(with: event)
    }
}
