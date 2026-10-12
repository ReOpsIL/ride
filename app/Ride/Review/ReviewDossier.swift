import SwiftUI

struct ReviewDossierPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var review: ReviewModel
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.m) {
                    if let row = review.selectedRow() {
                        identity(row)
                        if let dossier = review.dossier {
                            facts(dossier)
                        }
                        marks
                        noteBox(row)
                        ReviewShotBox(row: row, review: review)
                    } else {
                        Text("Select a symbol")
                            .font(Tokens.ui(12))
                            .foregroundStyle(ts.ui.textTertiary)
                    }
                }
                .padding(Tokens.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ts.ui.bgRaised)
        .onChange(of: review.selection) { _, _ in
            note = review.noteDraft
        }
        .onChange(of: review.noteDraft) { _, draft in
            if note != draft {
                note = draft
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Dossier")
                .font(Tokens.ui(11, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: Tokens.Size.panelHeader)
        .overlay(alignment: .bottom) { ts.ui.border.frame(height: Tokens.Size.hairline) }
    }

    private func identity(_ row: ReviewRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.item)
                .font(Tokens.mono(12, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            Text("\(row.kind) · \(row.place)")
                .font(Tokens.ui(10))
                .foregroundStyle(ts.ui.textTertiary)
            if !row.signature.isEmpty {
                Text(row.signature)
                    .font(Tokens.mono(11))
                    .foregroundStyle(ts.ui.textSecondary)
                    .textSelection(.enabled)
            }
            if !row.doc.isEmpty {
                Text(row.doc)
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textSecondary)
            }
        }
    }

    private func facts(_ dossier: ReviewDossier) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            block("Change", [dossier.change] + dossier.checks)
            block("Callers", dossier.callers)
            block("Callees", dossier.callees)
            block("Author's words", dossier.claims)
            if !dossier.since.isEmpty {
                block("Since verified", dossier.since)
            }
            markList(dossier.marks)
            VStack(alignment: .leading, spacing: 2) {
                Text("Note")
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                Text(dossier.note)
                    .font(Tokens.ui(11))
                    .foregroundStyle(dossier.note == "Missing" ? ts.ui.warning : ts.ui.textPrimary)
            }
        }
    }

    private func markList(_ lines: [ReviewMarkLine]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Marks")
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
            if lines.isEmpty {
                Text("none")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: Tokens.Space.s) {
                        Text(line.text)
                            .font(Tokens.mono(11))
                            .foregroundStyle(ts.ui.textPrimary)
                            .textSelection(.enabled)
                        Spacer(minLength: Tokens.Space.xs)
                        if line.own {
                            Button("Delete") {
                                state.review.drop(id: line.id, root: state.git.root)
                            }
                            .buttonStyle(.plain)
                            .font(Tokens.ui(10, weight: .semibold))
                            .foregroundStyle(ts.ui.accent)
                            .accessibilityLabel("Delete \(line.text)")
                        }
                    }
                }
            }
        }
    }

    private func block(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Tokens.ui(10, weight: .semibold))
                .foregroundStyle(ts.ui.textTertiary)
            if lines.isEmpty || lines == [""] {
                Text("none")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textTertiary)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? "none" : line)
                        .font(Tokens.mono(11))
                        .foregroundStyle(ts.ui.textPrimary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var marks: some View {
        HStack(spacing: Tokens.Space.s) {
            mark("Suspect", "suspect")
            mark("Question", "question")
            mark("Verified", "verified")
        }
    }

    private func mark(_ title: String, _ kind: String) -> some View {
        Button(title) {
            guard let row = review.selectedRow() else { return }
            state.review.mark(row, root: state.git.root, kind: kind, note: note)
        }
        .buttonStyle(.plain)
        .font(Tokens.ui(10, weight: .semibold))
        .foregroundStyle(ts.ui.accent)
        .disabled(review.selectedRow() == nil)
    }

    private func noteBox(_ row: ReviewRow) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            TextField("Note", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Tokens.ui(11))
                .lineLimit(2...6)
                .padding(Tokens.Space.s)
                .background(ts.ui.bgBase, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            HStack(spacing: Tokens.Space.s) {
                Button("Cite stop") {
                    note = ReviewTrail.cite(
                        frames: DebugPanelModel.shared.frames,
                        watches: DebugPanelModel.shared.watches
                    )
                }
                .disabled(DebugPanelModel.shared.frames.isEmpty)
                Button(review.noting ? "Writing…" : "Generate note") {
                    review.generateNote(row, root: state.git.root, config: state.prefs.aiChatConfig)
                }
                .disabled(review.noting)
                Button("Share note") {
                    review.noteDraft = note
                    review.shareNote(row, root: state.git.root)
                }
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .buttonStyle(.plain)
            .font(Tokens.ui(10, weight: .semibold))
            .foregroundStyle(ts.ui.textSecondary)
            if let cached = review.cachedNote(for: row), note.isEmpty {
                Text(cached)
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textSecondary)
            }
        }
    }
}
