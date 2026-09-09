import SwiftUI

struct SymbolInFileOverlay: View {
    @EnvironmentObject private var state: AppState

    private var rows: [OutlineRow] {
        let all = state.activeBuffer?.outline ?? []
        let q = state.symbolQuery.lowercased()
        if q.isEmpty {
            return Array(all.prefix(60))
        }
        return Array(all.filter { $0.name.lowercased().contains(q) || $0.kindLabel.contains(q) }.prefix(60))
    }

    var body: some View {
        PickerCard(
            query: $state.symbolQuery,
            placeholder: "Go to symbol in file",
            width: 480,
            onSubmit: confirm,
            onDismiss: { state.showSymbolInFile = false }
        ) {
            if rows.isEmpty {
                PickerEmpty(text: "No symbols")
            } else {
                PickerList(count: rows.count, selected: selectedIndex) { i in
                    let row = rows[i]
                    PickerRow(
                        title: row.name,
                        query: state.symbolQuery,
                        subtitle: row.kindLabel,
                        selected: state.symbolSelection == row.startByte,
                        action: {
                            state.symbolSelection = row.startByte
                            confirm()
                        }
                    ) {
                        KindBadge(kind: OutlineKind.itemKind(row.kindLabel))
                    }
                }
            }
        }
        .onAppear {
            state.symbolQuery = ""
            state.symbolSelection = rows.first?.startByte
        }
        .onChange(of: state.symbolQuery) { _, _ in
            state.symbolSelection = rows.first?.startByte
        }
        .onKeyPress(.downArrow) {
            move(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            move(-1)
            return .handled
        }
    }

    private var selectedIndex: Int? {
        rows.firstIndex { $0.startByte == state.symbolSelection }
    }

    private func move(_ delta: Int) {
        guard !rows.isEmpty else {
            return
        }
        let current = selectedIndex ?? 0
        state.symbolSelection = rows[(current + delta + rows.count) % rows.count].startByte
    }

    private func confirm() {
        let byte = state.symbolSelection ?? rows.first?.startByte
        state.showSymbolInFile = false
        if let byte {
            state.jumpTo(byte: byte)
        }
    }
}
