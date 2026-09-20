import SwiftUI

struct HierarchyPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "point.3.connected.trianglepath.dotted", title: "Hierarchy", badges: badges) {
                Picker("", selection: modeBinding) {
                    Text("Callers").tag(HierarchyMode.callers)
                    Text("Callees").tag(HierarchyMode.callees)
                    Text("Types").tag(HierarchyMode.types)
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(maxWidth: 168)
                .labelsHidden()
                IconButton(symbol: "xmark", help: "Hide Hierarchy", size: 9) {
                    state.hideHierarchy()
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ts.ui.bgBase)
    }

    private var modeBinding: Binding<HierarchyMode> {
        Binding(
            get: { state.hierarchy.mode },
            set: { state.setHierarchyMode($0) }
        )
    }

    private var badges: [PanelBadge] {
        if state.hierarchy.running {
            return [PanelBadge(id: "run", text: "searching…", tint: ts.ui.accent)]
        }
        guard state.hierarchy.finished, !state.hierarchy.rootName.isEmpty else {
            return []
        }
        return [PanelBadge(id: "n", text: state.hierarchy.rootName, tint: nil)]
    }

    @ViewBuilder
    private var content: some View {
        if !state.hierarchy.finished {
            placeholder("Call Hierarchy (⌃⌥H) or Type Hierarchy (⌃H)")
        } else if state.hierarchy.root == nil {
            placeholder("No hierarchy at the caret")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(state.hierarchy.rows) { row in
                        HierarchyRowView(row: row) {
                            state.openHierarchyRow(row.node)
                        } toggle: {
                            state.toggleHierarchyRow(row.id)
                        }
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .padding(Tokens.Space.l)
    }
}

struct HierarchyRowView: View {
    let row: HierarchyRow
    let open: () -> Void
    let toggle: () -> Void
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: row.expanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(width: 10)
                .opacity(row.expandable ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
            KindBadge(kind: OutlineKind.itemKind(row.node.kindLabel))
            Text(row.node.name)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(location)
                .font(Tokens.mono(10))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(1)
        }
        .padding(.leading, CGFloat(row.depth) * 12 + Tokens.Space.m)
        .padding(.trailing, Tokens.Space.m)
        .frame(height: Tokens.Size.sidebarRow)
        .background(hovering ? ts.ui.bgHover : Color.clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: open)
    }

    private var location: String {
        let file = row.node.path.split(separator: "/").last.map(String.init) ?? row.node.path
        guard !file.isEmpty else {
            return ""
        }
        return row.node.line == 0 ? file : "\(file):\(row.node.line)"
    }
}
