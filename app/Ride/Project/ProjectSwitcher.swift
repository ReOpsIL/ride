import SwiftUI

struct ProjectSwitcher: View {
    @ObservedObject var store: ProjectModelStore
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        if store.projects.count > 1 {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "shippingbox")
                    .font(.system(size: Tokens.Size.iconS))
                    .foregroundStyle(ts.ui.accent)
                Picker("", selection: selection) {
                    ForEach(store.projects, id: \.root) { project in
                        Text(store.title(project)).tag(project.root)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .help("Active project: builds, runs and checks use it")
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.top, Tokens.Space.xs)
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { store.model?.root ?? "" },
            set: { store.choose(root: $0) }
        )
    }
}
