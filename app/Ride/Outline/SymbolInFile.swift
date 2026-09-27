import SwiftUI

struct SymbolInFileOverlay: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let rows = state.symbolRows
        PickerCard(
            query: $state.symbolQuery,
            placeholder: "Go to symbol in file",
            width: 480,
            onSubmit: { state.confirmSymbolInFile() },
            onDismiss: { state.showSymbolInFile = false }
        ) {
            if rows.isEmpty {
                PickerEmpty(text: "No symbols")
            } else {
                PickerList(count: rows.count, selected: state.symbolSelectionIndex) { i in
                    let row = rows[i]
                    PickerRow(
                        title: row.name,
                        query: state.symbolQuery,
                        subtitle: row.kindLabel,
                        selected: state.symbolSelection == row.startByte,
                        action: {
                            state.symbolSelection = row.startByte
                            state.confirmSymbolInFile()
                        }
                    ) {
                        KindBadge(kind: OutlineKind.itemKind(row.kindLabel))
                    }
                }
            }
        }
        .onChange(of: state.symbolQuery) { _, _ in state.symbolQueryChanged() }
        .onKeyPress(.downArrow) {
            state.moveSymbolSelection(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            state.moveSymbolSelection(-1)
            return .handled
        }
    }
}
