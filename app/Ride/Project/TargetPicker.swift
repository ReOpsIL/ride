import SwiftUI

struct TargetPicker: View {
    let state: AppState
    @ObservedObject var store: ProjectModelStore

    var body: some View {
        if store.rows.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(store.groups) { group in
                    Section(group.title) {
                        ForEach(group.rows) { row in
                            Button {
                                state.selectTarget(row)
                            } label: {
                                Label(TargetRows.displayName(row), systemImage: TargetRows.symbol(row.kind))
                            }
                        }
                    }
                }
            } label: {
                Label(title, systemImage: TargetRows.symbol(store.defaultRow?.kind ?? .custom))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Run Target")
            .accessibilityLabel("Run Target")
        }
    }

    private var title: String {
        guard let row = store.defaultRow else {
            return "No Target"
        }
        return TargetRows.displayName(row)
    }
}
