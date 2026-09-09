import SwiftUI

struct PickerRow<Icon: View>: View {
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false
    let title: String
    let query: String
    var subtitle = ""
    var trailing = ""
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            icon()
                .frame(width: Tokens.Size.badge, height: Tokens.Size.badge)
            HighlightedText.name(title, query: query, base: ts.ui.textPrimary, accent: ts.ui.accent, font: Tokens.mono(12, weight: .semibold))
                .lineLimit(1)
                .layoutPriority(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Tokens.mono(11))
                    .foregroundStyle(ts.ui.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Tokens.Space.m)
            if !trailing.isEmpty {
                Text(trailing)
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textTertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.pickerRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            selected ? ts.ui.accent.opacity(0.28) : (hovering ? ts.ui.bgHover : Color.clear),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
        )
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }
}

struct PickerList<Row: View>: View {
    let count: Int
    let selected: Int?
    var maxRows = 12
    @ViewBuilder var row: (Int) -> Row

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { i in
                        row(i).id(i)
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
            .frame(height: CGFloat(min(count, maxRows)) * Tokens.Size.pickerRow + Tokens.Space.xs * 2)
            .onChange(of: selected) { _, value in
                if let value {
                    proxy.scrollTo(value)
                }
            }
        }
    }
}
