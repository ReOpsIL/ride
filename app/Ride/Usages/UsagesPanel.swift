import SwiftUI

struct UsagesPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: UsagesModel
    @ObservedObject private var ts = ThemeStore.shared
    @State private var showOther = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "arrow.triangle.branch", title: "Usages", badges: badges) {
                IconButton(symbol: "xmark", help: "Hide Usages", size: 9) {
                    state.showUsages = false
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        if model.running {
            return [PanelBadge(id: "run", text: "searching…", tint: ts.ui.accent)]
        }
        guard model.finished, !model.name.isEmpty else {
            return []
        }
        return [PanelBadge(id: "n", text: "\(model.name) · \(Plural.count(model.total, "usage"))", tint: nil)]
    }

    @ViewBuilder
    private var content: some View {
        if !model.finished {
            placeholder("Find Usages (⌥F7) to search")
        } else if model.total == 0 {
            placeholder("No usages of \(model.name.isEmpty ? "symbol" : model.name)")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.primary) { group in
                        UsageGroupView(group: group) { row in
                            state.openUsage(path: row.path, byte: row.byteStart)
                        }
                    }
                    if !model.other.isEmpty {
                        otherSection
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }

    @ViewBuilder
    private var otherSection: some View {
        Button {
            showOther.toggle()
        } label: {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: showOther ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                Text("Other matches · \(UsageGrouping.total(model.other))")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Space.l)
            .frame(height: Tokens.Size.sidebarRow)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if showOther {
            ForEach(model.other) { group in
                UsageGroupView(group: group) { row in
                    state.openUsage(path: row.path, byte: row.byteStart)
                }
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Tokens.Space.l)
    }
}

struct UsageGroupView: View {
    let group: UsageFileGroup
    let open: (UsageRow) -> Void
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(ts.ui.textTertiary)
            Text(group.name)
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            Text(group.path)
                .font(Tokens.mono(10))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(group.count)")
                .font(Tokens.mono(10))
                .foregroundStyle(ts.ui.textTertiary)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.sidebarRow)
        ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
            UsageRowView(row: row) { open(row) }
        }
    }
}

struct UsageRowView: View {
    let row: UsageRow
    let open: () -> Void
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Text("\(row.line)")
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(minWidth: 34, alignment: .trailing)
            Text(row.enclosingItem.isEmpty ? row.enclosingKind : row.enclosingItem)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Text(row.enclosingKind)
                .font(Tokens.mono(10))
                .foregroundStyle(ts.ui.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.leading, Tokens.Space.xl)
        .padding(.trailing, Tokens.Space.l)
        .frame(height: Tokens.Size.sidebarRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? ts.ui.bgHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: open)
    }
}
