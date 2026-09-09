import SwiftUI

struct ProjectFindOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: ProjectFindModel
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    state.showProjectFind = false
                }
            VStack(spacing: 0) {
                HStack {
                    TextField("Find in project", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .focused($focused)
                        .onSubmit {
                            submit()
                        }
                    if model.running {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(10)
                Divider()
                results
            }
            .frame(width: 720)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 16)
        }
        .onAppear {
            focused = true
        }
        .onExitCommand {
            state.showProjectFind = false
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

    @ViewBuilder
    private var results: some View {
        if model.matches.isEmpty {
            Text(model.query.isEmpty ? "Press Return to search" : (model.running ? "Searching…" : "No matches"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        } else {
            List(selection: $model.selection) {
                ForEach(model.groups, id: \.file) { group in
                    Section(header: Text(label(group.file)).font(.system(size: 11, weight: .semibold, design: .monospaced))) {
                        ForEach(group.matches) { match in
                            HStack(spacing: 8) {
                                Text("\(match.line)")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                                Text(match.preview)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .tag(Optional(match.id))
                            .onTapGesture {
                                open(match)
                            }
                        }
                    }
                }
                if model.truncated {
                    Text("Results truncated at \(ProjectFind.cap) matches")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 420)
        }
    }

    private func label(_ url: URL) -> String {
        guard let root = state.workspaceRoot else {
            return url.lastPathComponent
        }
        return WorkspaceFS.relativePath(root: root, file: url)
    }

    private func submit() {
        if model.needsRun || model.matches.isEmpty {
            model.run(root: state.workspaceRoot, showHidden: state.prefs.showHidden)
            return
        }
        if let match = model.selected {
            open(match)
        }
    }

    private func open(_ match: ProjectFindMatch) {
        state.showProjectFind = false
        state.pendingJump = match.byte
        state.openFile(match.file)
    }
}
