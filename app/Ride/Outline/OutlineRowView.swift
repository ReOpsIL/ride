import SwiftUI

struct OutlineRowView: View {
    let node: OutlineNode
    let expanded: Bool
    let toggle: () -> Void
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .animation(.easeOut(duration: 0.15), value: expanded)
                .frame(width: 12)
                .opacity(node.hasChildren ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { if node.hasChildren { toggle() } }
            OutlineKind.badge(node.kindLabel)
            Text(node.name)
                .font(Tokens.mono(11))
                .foregroundStyle(node.kindLabel == OutlineTree.scopeKind ? ts.ui.textSecondary : ts.ui.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.leading, Tokens.Space.xs + CGFloat(node.depth) * 12)
        .padding(.trailing, Tokens.Space.m)
        .frame(height: Tokens.Size.sidebarRow)
        .background(hovering ? ts.ui.bgHover : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            state.jumpTo(byte: node.startByte)
        }
    }
}
