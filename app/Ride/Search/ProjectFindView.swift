import SwiftUI

struct ProjectFindOverlay: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: ProjectFindModel
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        PickerCard(
            query: $model.query,
            placeholder: "Find in project",
            width: 760,
            hints: [
                PickerHint(id: "run", key: "↩", label: "search / open"),
                PickerHint(id: "nav", key: "↑↓", label: "navigate"),
                PickerHint(id: "esc", key: "esc", label: "dismiss"),
            ],
            trailing: summary,
            onSubmit: submit,
            onDismiss: { state.showProjectFind = false }
        ) {
            results
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

    private var summary: String? {
        if model.running {
            return "Searching…"
        }
        guard !model.matches.isEmpty else {
            return nil
        }
        let files = Set(model.matches.map(\.file)).count
        let count = Plural.count(model.matches.count, "match", plural: "matches")
        return "\(count) in \(Plural.count(files, "file"))\(model.truncated ? " (truncated)" : "")"
    }

    @ViewBuilder
    private var results: some View {
        if model.matches.isEmpty {
            PickerEmpty(text: model.query.isEmpty ? "Type a query and press Return" : (model.running ? "Searching…" : "No matches"))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.groups, id: \.file) { group in
                            FindGroupHeader(file: group.file, count: group.matches.count, label: label(group.file))
                            ForEach(group.matches) { match in
                                FindMatchRow(match: match, query: model.query, selected: model.selection == match.id) {
                                    open(match)
                                }
                                .id(match.id)
                            }
                        }
                    }
                    .padding(.vertical, Tokens.Space.xs)
                }
                .frame(height: min(CGFloat(model.matches.count + model.groups.count) * Tokens.Size.pickerRow + Tokens.Space.xs * 2, 440))
                .onChange(of: model.selection) { _, value in
                    if let value {
                        proxy.scrollTo(value)
                    }
                }
            }
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
