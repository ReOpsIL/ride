import SwiftUI

struct GitBranchMenu: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var status: GitStatusService
    @ObservedObject var model: GitChangesModel

    private var local: [GitBranch] {
        model.branches.filter { !$0.remote }
    }

    private var remote: [GitBranch] {
        model.branches.filter(\.remote)
    }

    var body: some View {
        Menu {
            Button("New Branch…") { state.gitNewBranch() }
            Button("Fetch") { state.gitFetch() }
            if !local.isEmpty {
                Divider()
                Section("Local") {
                    ForEach(local, id: \.name) { branch in
                        item(branch)
                    }
                }
            }
            if !remote.isEmpty {
                Divider()
                Section("Remote") {
                    ForEach(remote, id: \.name) { branch in
                        item(branch)
                    }
                }
            }
        } label: {
            Label(status.branch ?? "branch", systemImage: "arrow.triangle.branch")
                .font(Tokens.ui(11))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(model.isBusy)
        .help("Switch or create a branch")
    }

    @ViewBuilder
    private func item(_ branch: GitBranch) -> some View {
        if branch.current {
            Button {} label: {
                Label(branch.name, systemImage: "checkmark")
            }
            .disabled(true)
        } else {
            Button(branch.name) { state.gitCheckout(branch) }
        }
    }
}
