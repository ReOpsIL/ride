import SwiftUI

struct ReviewMapMarks: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let node: MapNode
    let scale: CGFloat

    var body: some View {
        let rows = matched
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 3 * scale) {
                HStack(spacing: 4 * scale) {
                    ForEach(pills(rows).prefix(3), id: \.self) { pill in
                        Button(pill) { open(rows) }
                            .buttonStyle(.plain)
                            .font(.system(size: 9 * scale, weight: .semibold))
                            .foregroundStyle(tint(pill))
                            .lineLimit(1)
                    }
                }
                GeometryReader { geo in
                    let share = uncheckedShare(rows)
                    ZStack(alignment: .leading) {
                        Capsule().fill(ts.ui.bgHover)
                        Capsule().fill(ts.ui.warning.opacity(0.85))
                            .frame(width: geo.size.width * share)
                    }
                }
                .frame(height: max(3, 4 * scale))
            }
        }
    }

    private var matched: [ReviewRow] {
        guard let inbox = state.review.inbox else {
            return []
        }
        return inbox.rows.filter { row in
            row.group != "equivalent" && covers(row)
        }
    }

    private func covers(_ row: ReviewRow) -> Bool {
        switch node.kind {
        case .function, .value, .type:
            return row.name == node.title && sameFile(row)
        case .file:
            return sameFile(row)
        case .module, .project:
            let name = ReviewGroups.moduleName(row.module)
            if node.title == name || node.title == row.module {
                return true
            }
            return sameFile(row)
        }
    }

    private func sameFile(_ row: ReviewRow) -> Bool {
        guard let path = node.path, let root = state.git.root else {
            return false
        }
        let abs = URL(fileURLWithPath: path).standardizedFileURL.path
        let fromRow = URL(fileURLWithPath: root).appendingPathComponent(row.path).standardizedFileURL.path
        return abs == fromRow
    }

    private func pills(_ rows: [ReviewRow]) -> [String] {
        var out: [String] = []
        let suspect = rows.filter { $0.mark == "suspect" }.count
        let question = rows.filter { $0.mark == "question" }.count
        let stale = rows.filter { $0.markState == "stale" }.count
        let unchecked = rows.filter { !covered($0) }.count
        let evidence = rows.filter { $0.markNote.contains("evidence") || state.review.shots[$0.reviewKey] != nil }.count
        let failing = state.review.hunt.contains { hit in rows.contains { $0.name == hit.name } }
        if suspect > 0 { out.append("\(suspect) suspect") }
        if question > 0 { out.append("\(question) question") }
        if unchecked > 0 { out.append("\(unchecked) unchecked") }
        if stale > 0 { out.append("\(stale) stale") }
        if evidence > 0 { out.append("evidence") }
        if failing { out.append("failing test") }
        if out.isEmpty { out.append("all verified") }
        return out
    }

    private func covered(_ row: ReviewRow) -> Bool {
        if row.mark == "verified", row.markState == "fresh" { return true }
        if row.mark == "suspect" || row.mark == "question" { return true }
        return false
    }

    private func uncheckedShare(_ rows: [ReviewRow]) -> CGFloat {
        guard !rows.isEmpty else { return 0 }
        let open = rows.filter { !covered($0) }.count
        return CGFloat(open) / CGFloat(rows.count)
    }

    private func tint(_ pill: String) -> Color {
        if pill.contains("suspect") || pill.contains("failing") { return ts.ui.error }
        if pill.contains("question") { return ts.ui.info }
        if pill.contains("stale") || pill.contains("unchecked") { return ts.ui.warning }
        if pill.contains("verified") { return ts.ui.success }
        return ts.ui.textSecondary
    }

    private func open(_ rows: [ReviewRow]) {
        state.showGit = true
        if node.kind == .module || node.kind == .project {
            state.review.focus(module: node.title, root: state.git.root)
        } else if let row = rows.first {
            state.review.segment = .symbols
            state.review.reload(root: state.git.root)
            state.openReviewRow(row)
        }
    }
}
