import SwiftUI

struct ReviewCounts: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var review: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.s) {
                chips
                Spacer(minLength: Tokens.Space.s)
                copy("Copy review summary") { review.copySummary(root: state.git.root) }
                copy("Copy agent brief") { review.copyBrief(root: state.git.root) }
                    .foregroundStyle(ts.ui.accent)
            }
            if let order = review.inbox?.order, !order.isEmpty {
                Text(order)
                    .font(Tokens.ui(10))
                    .foregroundStyle(ts.ui.textTertiary)
            }
            if let notice = review.notice {
                Text(notice)
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(ts.ui.success)
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
    }

    @ViewBuilder
    private var chips: some View {
        if let inbox = review.inbox {
            chip("\(inbox.needsEyes)", "need eyes", ts.ui.warning)
            chip("\(inbox.verified)", "verified", ts.ui.success)
            chip("\(inbox.suspect)", "suspect", ts.ui.error)
            chip("\(inbox.question)", "question", ts.ui.info)
            chip("\(inbox.unchecked)", "unchecked", ts.ui.textSecondary)
        }
    }

    private func chip(_ count: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(count).font(Tokens.ui(11, weight: .semibold)).foregroundStyle(tint)
            Text(label).font(Tokens.ui(10)).foregroundStyle(ts.ui.textSecondary)
        }
    }

    private func copy(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(Tokens.ui(10, weight: .semibold))
            .foregroundStyle(ts.ui.textSecondary)
    }
}
