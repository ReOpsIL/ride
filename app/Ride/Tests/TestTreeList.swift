import SwiftUI

struct TestTreeList: View {
    let groups: [TestGroup]
    @Binding var selected: String?
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groups) { group in
                    if !group.suite.isEmpty {
                        Text(group.suite)
                            .font(Tokens.ui(11, weight: .semibold))
                            .foregroundStyle(ts.ui.textSecondary)
                            .padding(.horizontal, Tokens.Space.l)
                            .padding(.top, Tokens.Space.s)
                    }
                    ForEach(group.rows) { row in
                        TestRowView(row: row, selected: selected == row.id) {
                            selected = row.id
                        }
                    }
                }
            }
            .padding(.vertical, Tokens.Space.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TestRowView: View {
    let row: TestRow
    let selected: Bool
    let action: () -> Void
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(row.name)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let duration = row.durationMs {
                Text("\(duration) ms")
                    .font(Tokens.mono(10))
                    .foregroundStyle(ts.ui.textTertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.sidebarRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? ts.ui.bgSelection : (hovering ? ts.ui.bgHover : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }

    private var symbol: String {
        switch row.outcome {
        case .running:
            return "circle.dotted"
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .ignored:
            return "minus.circle"
        }
    }

    private var tint: Color {
        switch row.outcome {
        case .running:
            return ts.ui.accent
        case .passed:
            return ts.ui.success
        case .failed:
            return ts.ui.error
        case .ignored:
            return ts.ui.textTertiary
        }
    }
}
