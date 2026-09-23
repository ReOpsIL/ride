import SwiftUI

struct TargetPicker: View {
    let state: AppState
    @ObservedObject var store: ProjectModelStore

    var body: some View {
        if store.rows.isEmpty, store.projects.count < 2 {
            EmptyView()
        } else {
            Menu {
                if store.projects.count > 1 {
                    Section("Project") {
                        ForEach(store.projects, id: \.root) { project in
                            Toggle(store.title(project), isOn: active(project))
                        }
                    }
                }
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

    private func active(_ project: ProjectModel) -> Binding<Bool> {
        Binding(
            get: { store.model?.root == project.root },
            set: { if $0 { store.choose(root: project.root) } }
        )
    }

    private var title: String {
        guard let row = store.defaultRow else {
            return "No Target"
        }
        return TargetRows.displayName(row)
    }
}
