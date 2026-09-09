import SwiftUI

struct SymbolPickerOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: SymbolPickerModel

    var body: some View {
        PickerCard(
            query: $model.query,
            placeholder: "Go to symbol in project  (fn: struct: trait: …)",
            width: 640,
            hints: [
                PickerHint(id: "nav", key: "↑↓", label: "navigate"),
                PickerHint(id: "open", key: "↩", label: "open"),
                PickerHint(id: "copy", key: "⌘C", label: "copy path"),
                PickerHint(id: "esc", key: "esc", label: "dismiss"),
            ],
            trailing: model.hits.isEmpty ? nil : Plural.count(model.hits.count, "symbol"),
            onSubmit: confirm,
            onDismiss: { state.showSymbolPicker = false }
        ) {
            if model.hits.isEmpty {
                PickerEmpty(text: model.query.isEmpty ? "Search the workspace and crate catalog" : "No symbols")
            } else {
                PickerList(count: model.hits.count, selected: model.selection) { i in
                    let hit = model.hits[i]
                    PickerRow(
                        title: hit.name,
                        query: model.query,
                        subtitle: hit.path == hit.name ? hit.signature : hit.path,
                        trailing: CompletionRowStyle.origin(hit),
                        selected: model.selection == i,
                        action: {
                            model.selection = i
                            confirm()
                        }
                    ) {
                        KindBadge(kind: hit.itemKind)
                    }
                    .help(hit.docFirstSentence)
                }
                .onCopyCommand {
                    guard let hit = model.selected else {
                        return []
                    }
                    return [NSItemProvider(object: hit.path as NSString)]
                }
            }
        }
        .onChange(of: model.query) { _, _ in model.refresh() }
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
