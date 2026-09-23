import SwiftUI

struct ProjectTreeView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var projects: ProjectModelStore

    var body: some View {
        let roots = Set(projects.projects.count > 1 ? projects.projects.map(\.root) : [])
        let active = roots.isEmpty ? nil : projects.model?.root
        ZStack(alignment: .topLeading) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(FileTreeRows.visible(state.rootNodes, expanded: state.expanded)) { item in
                    TreeRow(
                        node: item.node,
                        depth: item.depth,
                        mark: TreeProjectMark(path: item.node.url.path, roots: roots, active: active)
                    )
                }
            }
            .padding(.vertical, Tokens.Space.xs)
            TreeKeyHost()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
    }
}
