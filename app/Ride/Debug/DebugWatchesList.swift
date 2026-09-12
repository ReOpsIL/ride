import SwiftUI

struct DebugWatchesList: View {
    @ObservedObject var model: DebugPanelModel
    @ObservedObject private var ts = ThemeStore.shared
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Space.xs) {
                Text("Watches")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textSecondary)
                TextField("expression", text: $draft)
                    .font(Tokens.mono(11))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                IconButton(symbol: "plus", help: "Add Watch", action: add)
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xs)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.watches) { row in
                        DebugWatchRow(row: row) {
                            model.removeWatch(id: row.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func add() {
        model.addWatch(draft)
        draft = ""
    }
}

struct DebugWatchRow: View {
    let row: WatchRow
    let remove: () -> Void
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Text(row.expression)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Text(row.value)
                .font(Tokens.mono(11))
                .foregroundStyle(row.failed ? ts.ui.error : ts.ui.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            IconButton(symbol: "xmark", help: "Remove Watch", size: 9, action: remove)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
