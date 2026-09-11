import SwiftUI

struct ProjectReplacePreview: View {
    @ObservedObject var model: ProjectFindModel
    @ObservedObject private var ts = ThemeStore.shared
    let root: URL?
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Replace in Project")
                .font(Tokens.ui(15, weight: .semibold))
            Text(summary)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textSecondary)
            list
            HStack {
                Button("Select All") { select(true) }
                Button("Select None") { select(false) }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Replace", action: onApply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.chosenHits.isEmpty)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 560, height: 420)
    }

    private var summary: String {
        let files = model.chosenHits
        let matches = files.reduce(0) { $0 + $1.ranges.count }
        return "\(Plural.count(matches, "match", plural: "matches")) in \(Plural.count(files.count, "file"))"
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                ForEach(model.hits, id: \.file) { hit in
                    row(hit)
                }
            }
        }
    }

    private func row(_ hit: FileHit) -> some View {
        Toggle(isOn: binding(hit.file)) {
            HStack {
                Text(label(hit.file))
                    .font(Tokens.mono(12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Tokens.Space.m)
                Text("\(hit.ranges.count)")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
            }
        }
        .toggleStyle(.checkbox)
    }

    private func binding(_ file: URL) -> Binding<Bool> {
        Binding(
            get: { model.included.contains(file) },
            set: { model.setIncluded(file, $0) }
        )
    }

    private func label(_ url: URL) -> String {
        guard let root else {
            return url.lastPathComponent
        }
        return WorkspaceFS.relativePath(root: root, file: url)
    }

    private func select(_ on: Bool) {
        if on {
            model.included = Set(model.hits.map(\.file))
        } else {
            model.included = []
        }
    }
}
