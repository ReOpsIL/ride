import SwiftUI

struct TabItem: View {
    @ObservedObject var buffer: BufferDocument
    let selected: Bool
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        let icon = FileIcon.spec(for: buffer, chrome: ts.chrome)
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: icon.symbol)
                .font(.system(size: Tokens.Size.iconS))
                .foregroundStyle(Color(icon.color).opacity(selected ? 1 : 0.7))
            Text(buffer.displayName)
                .font(Tokens.ui(12, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? ts.ui.textPrimary : ts.ui.textSecondary)
                .lineLimit(1)
            if buffer.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.system(size: Tokens.Size.iconS))
                    .foregroundStyle(ts.ui.textTertiary)
            }
            trailing
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.tab)
        .background(selected ? ts.editorBackground : (hovering ? ts.ui.bgHover : Color.clear))
        .overlay(alignment: .top) {
            if selected {
                ts.ui.accent.frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            ts.ui.border.frame(width: Tokens.Size.hairline)
        }
        .background(MiddleClick {
            state.closeBuffer(buffer.id)
        })
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            state.selectBuffer(buffer.id)
        }
        .contextMenu {
            Button("Close") { state.closeBuffer(buffer.id) }
            Button("Close Others") { state.closeOthers(keeping: buffer.id) }
            Button("Close All") { state.closeAll() }
            if let url = buffer.fileURL {
                Divider()
                Button("Copy Path") { TreeActions.copyPath(url, root: nil) }
                Button("Copy Relative Path") { TreeActions.copyPath(url, root: state.workspaceRoot) }
                Button("Reveal in Finder") { TreeActions.reveal(url) }
            }
        }
        .help(buffer.fileURL?.path ?? buffer.displayName)
    }

    @ViewBuilder
    private var trailing: some View {
        if hovering || (selected && !buffer.isDirty) {
            IconButton(symbol: "xmark", help: "Close", size: 9) {
                state.closeBuffer(buffer.id)
            }
        } else if buffer.isDirty {
            Circle()
                .fill(ts.ui.warning)
                .frame(width: 7, height: 7)
        }
    }
}
