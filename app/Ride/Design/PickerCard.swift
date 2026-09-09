import SwiftUI

struct PickerHint: Identifiable {
    let id: String
    let key: String
    let label: String
}

struct PickerCard<Content: View>: View {
    @ObservedObject private var ts = ThemeStore.shared
    @Binding var query: String
    let placeholder: String
    var width: CGFloat = 560
    var hints: [PickerHint] = [
        PickerHint(id: "nav", key: "↑↓", label: "navigate"),
        PickerHint(id: "open", key: "↩", label: "open"),
        PickerHint(id: "esc", key: "esc", label: "dismiss"),
    ]
    var trailing: String?
    let onSubmit: () -> Void
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            OverlayBackdrop(dismiss: onDismiss)
            VStack(spacing: 0) {
                OverlayCard(width: width) {
                    VStack(spacing: 0) {
                        field
                        ts.ui.border.frame(height: Tokens.Size.hairline)
                        content()
                        ts.ui.border.frame(height: Tokens.Size.hairline)
                        footer
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 80)
        }
        .onAppear { focused = true }
        .onExitCommand(perform: onDismiss)
    }

    private var field: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(Tokens.ui(16))
                .foregroundStyle(ts.ui.textPrimary)
                .focused($focused)
                .onSubmit(onSubmit)
            if let trailing {
                Text(trailing)
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.xl)
        .frame(height: 44)
    }

    private var footer: some View {
        HStack(spacing: Tokens.Space.xl) {
            ForEach(hints) { hint in
                HStack(spacing: Tokens.Space.xs) {
                    Text(hint.key)
                        .font(Tokens.ui(10, weight: .semibold))
                        .padding(.horizontal, Tokens.Space.xs)
                        .padding(.vertical, 1)
                        .background(ts.ui.bgHover, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
                    Text(hint.label)
                        .font(Tokens.ui(10))
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(ts.ui.textTertiary)
        .padding(.horizontal, Tokens.Space.xl)
        .frame(height: 24)
    }
}

struct PickerEmpty: View {
    @ObservedObject private var ts = ThemeStore.shared
    let text: String

    var body: some View {
        Text(text)
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Space.xl)
            .frame(height: 36)
    }
}
