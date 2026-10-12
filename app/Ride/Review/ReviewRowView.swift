import SwiftUI

struct ReviewRowView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let row: ReviewRow
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: Tokens.Space.s) {
                Text(row.item)
                    .font(Tokens.mono(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textPrimary)
                    .lineLimit(1)
                Text(row.change)
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textTertiary)
                Spacer(minLength: Tokens.Space.xs)
                Text(ReviewStyle.markLabel(row))
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(markTint)
                    .lineLimit(1)
            }
            HStack(spacing: Tokens.Space.s) {
                Text(row.place)
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForEach(row.checks, id: \.self) { check in
                    Text(check)
                        .font(Tokens.ui(9, weight: .semibold))
                        .foregroundStyle(ts.ui.error)
                        .lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.xs)
                Text("\(row.callers)")
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textSecondary)
                    .help("Callers by name")
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.xs)
        .background(fill, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
        .padding(.horizontal, Tokens.Space.xs)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { state.openReviewRow(row) }
        .contextMenu { menu }
        .accessibilityLabel("\(row.item) \(row.change)")
    }

    private var fill: Color {
        if selected {
            return ts.ui.bgSelection
        }
        return hovering ? ts.ui.bgHover : .clear
    }

    private var markTint: Color {
        if row.markState == "stale" {
            return ts.ui.warning
        }
        switch row.mark {
        case "suspect":
            return ts.ui.error
        case "question":
            return ts.ui.info
        case "verified":
            return ts.ui.success
        case "note":
            return ts.ui.accent
        default:
            return ts.ui.textTertiary
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Suspect") { state.reviewMark(row, kind: "suspect") }
        Button("Question") { state.reviewMark(row, kind: "question") }
        Button("Verified") { state.reviewMark(row, kind: "verified") }
        if !row.markId.isEmpty {
            Button("Drop mark") { state.review.drop(row, root: state.git.root) }
        }
    }
}
