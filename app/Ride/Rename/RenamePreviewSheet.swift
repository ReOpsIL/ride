import SwiftUI

struct RenamePreviewSheet: View {
    @ObservedObject var model: RenamePreviewModel
    @ObservedObject private var ts = ThemeStore.shared
    let root: URL?
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Rename \(model.selection.name) to \(model.selection.newName)")
                .font(Tokens.ui(15, weight: .semibold))
            Text(summary)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textSecondary)
            if model.selection.showBanner {
                banner
            }
            list
            HStack {
                Button("Select All") { model.selection.selectAllFiles(true) }
                    .disabled(model.selection.files.isEmpty)
                Button("Select None") { model.selection.selectAllFiles(false) }
                    .disabled(model.selection.files.isEmpty)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: onApply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.selection.canApply)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 560, height: 460)
    }

    private var summary: String {
        let count = model.selection.chosenEditCount
        let files = model.selection.chosenFilePaths.count
        return "\(Plural.count(count, "occurrence")) in \(Plural.count(files, "file"))"
    }

    private var banner: some View {
        Text("No occurrence was verified as the same symbol. Nothing will change until you tick an entry in Review.")
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textSecondary)
            .padding(Tokens.Space.m)
            .background(ts.ui.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.m))
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.l) {
                if !model.selection.files.isEmpty {
                    filesSection
                }
                if !model.selection.review.isEmpty {
                    reviewSection
                }
            }
        }
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("Occurrences")
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textSecondary)
            ForEach(model.selection.files, id: \.path) { file in
                fileRow(file)
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack {
                Text("Review — could not verify these are the same symbol")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textSecondary)
                Spacer()
                Button(model.selection.allReviewSelected ? "None" : "All") {
                    model.selection.selectAllReview(!model.selection.allReviewSelected)
                }
                .font(Tokens.ui(11))
                .buttonStyle(.plain)
                .foregroundStyle(ts.ui.accent)
            }
            ForEach(model.selection.review, id: \.id) { row in
                reviewRow(row)
            }
        }
    }

    private func fileRow(_ file: RenamePreviewFile) -> some View {
        Toggle(isOn: fileBinding(file.path)) {
            HStack {
                Text(label(file.path))
                    .font(Tokens.mono(12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Tokens.Space.m)
                Text("\(file.count)")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
            }
        }
        .toggleStyle(.checkbox)
    }

    private func reviewRow(_ row: RenameReviewRow) -> some View {
        Toggle(isOn: reviewBinding(row.id)) {
            Text(row.label)
                .font(Tokens.mono(12))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(ts.ui.textSecondary)
        }
        .toggleStyle(.checkbox)
    }

    private func fileBinding(_ path: String) -> Binding<Bool> {
        Binding(
            get: { model.selection.isFile(path) },
            set: { model.selection.setFile(path, $0) }
        )
    }

    private func reviewBinding(_ id: Int) -> Binding<Bool> {
        Binding(
            get: { model.selection.isReview(id) },
            set: { model.selection.setReview(id, $0) }
        )
    }

    private func label(_ path: String) -> String {
        path
    }
}
