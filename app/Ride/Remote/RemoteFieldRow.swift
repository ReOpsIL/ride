import SwiftUI

struct RemoteFieldRow<Field: View>: View {
    let title: String
    let help: String
    @ViewBuilder let field: () -> Field
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(title)
                .font(Tokens.ui(11))
                .gridColumnAlignment(.trailing)
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                field()
                Text(LocalizedStringKey(help))
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RemoteTextField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(prompt))
            .font(Tokens.mono(11))
            .textFieldStyle(.roundedBorder)
    }
}
