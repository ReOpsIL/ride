import SwiftUI

struct ReviewList: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var review: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReviewCounts(review: review)
            ts.ui.border.frame(height: Tokens.Size.hairline)
            bodyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let error = review.error, review.inbox == nil {
            placeholder(error)
        } else if review.loading, review.inbox == nil {
            ProgressView("Reading symbols")
                .font(Tokens.ui(12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else if let inbox = review.inbox {
            if inbox.rows.isEmpty {
                placeholder("No symbol changes against \(inbox.upstream)")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        filterBanner
                        huntBanner(inbox)
                        frameBanner(inbox)
                        section("behaviour", title: "Behaviour", count: inbox.behaviour, detail: "the review list", open: behaviour)
                        section("light", title: "Light", count: inbox.light, detail: lightDetail(inbox), open: light)
                        section("equivalent", title: "Equivalent", count: inbox.equivalent, detail: "never counted as needing eyes", open: equivalent)
                    }
                    .padding(.vertical, Tokens.Space.xs)
                }
            }
        } else {
            placeholder("Symbols against the upstream")
        }
    }

    private var behaviour: Binding<Bool> { Binding(get: { review.behaviourOpen }, set: { review.behaviourOpen = $0 }) }
    private var light: Binding<Bool> { Binding(get: { review.lightOpen }, set: { review.lightOpen = $0 }) }
    private var equivalent: Binding<Bool> { Binding(get: { review.equivalentOpen }, set: { review.equivalentOpen = $0 }) }

    @ViewBuilder
    private var filterBanner: some View {
        if let module = review.moduleFilter {
            HStack {
                Text(module)
                    .font(Tokens.ui(11, weight: .semibold))
                Spacer()
                Button("All modules") { review.moduleFilter = nil }
                    .buttonStyle(.plain)
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(ts.ui.accent)
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xs)
        }
    }

    @ViewBuilder
    private func huntBanner(_ inbox: ReviewInbox) -> some View {
        if let first = review.hunt.first {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(first.failing) · \(first.baseLabel)")
                    .font(Tokens.ui(10, weight: .semibold))
                    .foregroundStyle(ts.ui.error)
                ForEach(review.hunt, id: \.reviewKey) { hit in
                    if let row = inbox.rows.first(where: { $0.path == hit.path && $0.item == hit.item }) {
                        ReviewRowView(row: row, selected: review.selection == row.reviewKey)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func frameBanner(_ inbox: ReviewInbox) -> some View {
        if !review.frameNames.isEmpty {
            let names = Set(review.frameNames)
            let rows = inbox.rows.filter { $0.group == "behaviour" && names.contains($0.name) }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("On the stack")
                        .font(Tokens.ui(10, weight: .semibold))
                        .foregroundStyle(ts.ui.warning)
                    Spacer()
                    Button("Clear") { review.frameNames = [] }
                        .buttonStyle(.plain)
                        .font(Tokens.ui(10))
                }
                .padding(.horizontal, Tokens.Space.m)
                ForEach(rows, id: \.reviewKey) { row in
                    ReviewRowView(row: row, selected: review.selection == row.reviewKey)
                }
            }
        }
    }

    private func section(_ group: String, title: String, count: UInt32, detail: String, open: Binding<Bool>) -> some View {
        let inbox = review.inbox
        let rows = inbox.map { ReviewGroups.rows($0, group: group, module: review.moduleFilter) } ?? []
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                open.wrappedValue.toggle()
            } label: {
                HStack(spacing: Tokens.Space.s) {
                    Image(systemName: open.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ts.ui.textTertiary)
                    Text("\(title) · \(count)")
                        .font(Tokens.ui(11, weight: .semibold))
                        .foregroundStyle(ts.ui.textPrimary)
                    Text(detail)
                        .font(Tokens.ui(10))
                        .foregroundStyle(ts.ui.textTertiary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, Tokens.Space.m)
                .frame(height: Tokens.Size.sidebarRow)
            }
            .buttonStyle(.plain)
            if open.wrappedValue, let inbox {
                let blocks = ReviewGroups.blocks(rows, group: group, grouped: inbox.grouped)
                ForEach(blocks, id: \.id) { block in
                    if !block.title.isEmpty, group == "behaviour" || group == "equivalent" {
                        Text(block.title)
                            .font(Tokens.ui(10, weight: .semibold))
                            .foregroundStyle(ts.ui.textSecondary)
                            .padding(.horizontal, Tokens.Space.l)
                            .padding(.top, Tokens.Space.xs)
                    }
                    ForEach(block.rows, id: \.reviewKey) { row in
                        ReviewRowView(row: row, selected: review.selection == row.reviewKey)
                    }
                }
            }
        }
    }

    private func lightDetail(_ inbox: ReviewInbox) -> String {
        "docs \(inbox.docs) · imports \(inbox.imports) · tests \(inbox.tests) · still needs eyes"
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(Tokens.ui(12))
            .foregroundStyle(ts.ui.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Tokens.Space.l)
    }
}
