import SwiftUI

struct SymbolInFileOverlay: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var focused: Bool

    private var rows: [OutlineRow] {
        let all = state.activeBuffer?.outline ?? []
        let q = state.symbolQuery.lowercased()
        if q.isEmpty {
            return Array(all.prefix(40))
        }
        return Array(all.filter { $0.name.lowercased().contains(q) || $0.kindLabel.contains(q) }.prefix(40))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    state.showSymbolInFile = false
                }
            VStack(spacing: 0) {
                TextField("Go to symbol", text: $state.symbolQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(10)
                    .focused($focused)
                    .onSubmit {
                        confirm()
                    }
                Divider()
                if rows.isEmpty {
                    Text("No symbols")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeStore.shared.ui.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                } else {
                    List(rows, id: \.startByte, selection: $state.symbolSelection) { row in
                        HStack {
                            Text(row.kindLabel)
                                .foregroundStyle(ThemeStore.shared.ui.textSecondary)
                                .frame(width: 48, alignment: .leading)
                            Text(row.name)
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .tag(Optional(row.startByte))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: 280)
                }
            }
            .frame(width: 480)
            .background(ThemeStore.shared.ui.bgOverlay)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl).stroke(ThemeStore.shared.ui.border, lineWidth: 1))
            .shadow(radius: 16)
        }
        .onAppear {
            focused = true
            state.symbolQuery = ""
            state.symbolSelection = rows.first?.startByte
        }
        .onChange(of: state.symbolQuery) { _, _ in
            if let first = rows.first {
                state.symbolSelection = first.startByte
            }
        }
        .onExitCommand {
            state.showSymbolInFile = false
        }
    }

    private func confirm() {
        let byte = state.symbolSelection ?? rows.first?.startByte
        state.showSymbolInFile = false
        if let byte {
            state.jumpTo(byte: byte)
        }
    }
}
