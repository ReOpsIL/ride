import SwiftUI

struct FileOutlineView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "list.bullet.indent", title: "Outline", badges: badges) {
                IconButton(symbol: "xmark", help: "Hide Outline", size: 9) {
                    state.updatePrefs { $0.outlinePanel = false }
                }
            }
            if let buffer = state.activeBuffer {
                OutlineList(buffer: buffer)
            } else {
                Text("No file")
                    .font(Tokens.ui(12))
                    .foregroundStyle(ts.ui.textTertiary)
                    .padding(Tokens.Space.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        guard let count = state.activeBuffer?.outline.count, count > 0 else {
            return []
        }
        return [PanelBadge(id: "count", text: "\(count)", tint: nil)]
    }
}

struct OutlineList: View {
    @ObservedObject var buffer: BufferDocument
    @ObservedObject private var ts = ThemeStore.shared
    @State private var collapsed: Set<String> = []

    var body: some View {
        if buffer.outline.isEmpty {
            Text("No symbols")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .padding(Tokens.Space.l)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(OutlineTree.visible(OutlineTree.nodes(buffer.outline), collapsed: collapsed)) { node in
                        OutlineRowView(node: node, expanded: !collapsed.contains(node.id)) {
                            collapsed.formSymmetricDifference([node.id])
                        }
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }
}
