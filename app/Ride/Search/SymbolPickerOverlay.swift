import SwiftUI

struct SymbolPickerOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: SymbolPickerModel
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    state.showSymbolPicker = false
                }
            VStack(spacing: 0) {
                TextField("Go to symbol in project (fn: struct: trait: …)", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(10)
                    .focused($focused)
                    .onSubmit {
                        confirm()
                    }
                Divider()
                if model.hits.isEmpty {
                    Text(model.query.isEmpty ? "Type to search the workspace and catalog" : "No symbols")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeStore.shared.ui.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                } else {
                    List(model.hits.indices, id: \.self, selection: $model.selection) { i in
                        SymbolHitRow(hit: model.hits[i])
                            .tag(Optional(i))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: 320)
                    .onCopyCommand {
                        guard let hit = model.selected else {
                            return []
                        }
                        return [NSItemProvider(object: hit.path as NSString)]
                    }
                }
            }
            .frame(width: 620)
            .background(ThemeStore.shared.ui.bgOverlay)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl).stroke(ThemeStore.shared.ui.border, lineWidth: 1))
            .shadow(radius: 16)
        }
        .onAppear {
            focused = true
        }
        .onChange(of: model.query) { _, _ in
            model.refresh()
        }
        .onExitCommand {
            state.showSymbolPicker = false
        }
        .onKeyPress(.downArrow) {
            model.move(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            model.move(-1)
            return .handled
        }
    }

    private func confirm() {
        let hit = model.selected
        state.showSymbolPicker = false
        if let hit {
            HitNavigation.open(hit, state: state)
        }
    }
}

struct SymbolHitRow: View {
    let hit: CompletionHit

    var body: some View {
        HStack(spacing: 8) {
            Text(CompletionRowStyle.glyph(hit.itemKind))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: CompletionRowStyle.color(hit.itemKind)))
                .frame(width: 28)
            Text(hit.name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(hit.path == hit.name ? hit.signature : hit.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ThemeStore.shared.ui.textSecondary)
                .lineLimit(1)
            Spacer()
            Text(CompletionRowStyle.origin(hit))
                .font(.system(size: 10))
                .foregroundStyle(ThemeStore.shared.ui.textTertiary)
        }
        .help(hit.docFirstSentence)
    }
}
