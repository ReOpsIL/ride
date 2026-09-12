import SwiftUI

struct TargetsPanel: View {
    @ObservedObject var store: ProjectModelStore
    @ObservedObject private var ts = ThemeStore.shared

    private let maxHeight: CGFloat = 220

    var body: some View {
        if store.rows.isEmpty, store.notice == nil {
            EmptyView()
        } else {
            panel
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
            PanelHeader(icon: "square.stack.3d.up", title: "Targets", badges: badges) {
                EmptyView()
            }
            optionsRow
            if let notice = store.notice {
                Text(notice)
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Tokens.Space.m)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.groups) { group in
                        TargetGroupView(group: group, store: store)
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .topLeading)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        guard !store.rows.isEmpty else {
            return []
        }
        return [PanelBadge(id: "count", text: "\(store.rows.count)", tint: nil)]
    }

    @ViewBuilder private var optionsRow: some View {
        if !store.kindLabel.isEmpty || store.profiles.count > 1 {
            HStack(spacing: Tokens.Space.s) {
                Text(store.kindLabel)
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                profilePicker
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xs)
        }
    }

    @ViewBuilder private var profilePicker: some View {
        if store.profiles.count > 1 {
            Picker("", selection: $store.profile) {
                ForEach(store.profiles, id: \.self) { profile in
                    Text(profile).tag(profile)
                }
            }
            .labelsHidden()
            .controlSize(.mini)
            .frame(width: 110)
        }
    }
}

struct TargetGroupView: View {
    let group: TargetGroup
    @ObservedObject var store: ProjectModelStore
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        Text(group.title)
            .font(Tokens.ui(10, weight: .semibold))
            .foregroundStyle(ts.ui.textTertiary)
            .padding(.horizontal, Tokens.Space.m)
            .padding(.top, Tokens.Space.s)
        ForEach(group.rows) { row in
            TargetRowView(row: row, store: store)
        }
    }
}

struct TargetRowView: View {
    let row: TargetRow
    @ObservedObject var store: ProjectModelStore
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: TargetRows.symbol(row.kind))
                .font(.system(size: Tokens.Size.iconS))
                .foregroundStyle(ts.ui.textSecondary)
            Text(TargetRows.displayName(row))
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.xs)
        .background(background)
        .contentShape(Rectangle())
        .help(row.detail)
        .onHover { hovering = $0 }
        .onTapGesture { store.select(row) }
    }

    private var background: Color {
        if store.selected == row {
            return ts.ui.bgSelection
        }
        return hovering ? ts.ui.bgHover : .clear
    }
}
