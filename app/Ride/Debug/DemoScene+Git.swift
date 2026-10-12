import AppKit

extension DemoScene {
    static func gitScene(_ name: String, state: AppState) -> Bool {
        guard name == "git" else {
            return false
        }
        state.prefs.outlinePanel = false
        editor(state, file: "src/util.rs", line: 14)
        DemoLaunch.after(1.0) { state.showGit = true }
        ready(when: { gitStaged(state) })
        return true
    }

    private static func gitStaged(_ state: AppState) -> Bool {
        if state.gitChanges.diff != nil {
            return true
        }
        guard state.gitChanges.selection == nil,
              let change = state.git.repo?.changes.first(where: { $0.path.hasSuffix("util.rs") && $0.unstaged != nil })
        else {
            return false
        }
        state.selectGitChange(change, side: .unstaged)
        return false
    }

    static func reviewScene(_ name: String, state: AppState) -> Bool {
        guard name == "review" else {
            return false
        }
        state.prefs.outlinePanel = false
        state.review.segment = .symbols
        state.showGit = true
        ready(when: {
            guard let inbox = state.review.inbox else {
                return false
            }
            if state.review.selection == nil, let row = inbox.rows.first(where: { $0.group == "behaviour" }) ?? inbox.rows.first {
                state.openReviewRow(row)
                return false
            }
            guard state.review.dossier != nil || state.review.error != nil else {
                return false
            }
            if state.review.notice == nil {
                state.review.copySummary(root: state.git.root)
                return false
            }
            reviewStatus(state, inbox: inbox)
            return true
        })
        return true
    }

    private static func reviewStatus(_ state: AppState, inbox: ReviewInbox) {
        var lines = [
            "upstream \(inbox.upstream)",
            "needs \(inbox.needsEyes) verified \(inbox.verified) suspect \(inbox.suspect) question \(inbox.question) unchecked \(inbox.unchecked)",
            "behaviour \(inbox.behaviour) light \(inbox.light) equivalent \(inbox.equivalent) docs \(inbox.docs) imports \(inbox.imports) formatting \(inbox.formatting) moved \(inbox.moved)",
            "rows \(inbox.rows.count) order \(inbox.order)",
            "selected \(state.review.selection ?? "")",
            "notice \(state.review.notice ?? "")",
            "error \(state.review.error ?? "")",
            "dossier \(state.review.dossier?.signature ?? "")",
            "callers \(state.review.dossier?.callers.joined(separator: ", ") ?? "")",
            "checks \(state.review.dossier?.checks.joined(separator: ", ") ?? "")",
        ]
        for row in inbox.rows.prefix(12) {
            lines.append("\(row.group) \(row.change) \(row.item) \(row.checks.joined(separator: "|")) \(row.mark)")
        }
        let ride = inbox.rows.contains { $0.path.hasPrefix(".ride/") || $0.path.contains("/.ride/") }
        lines.append("ride-listed \(ride)")
        try? lines.joined(separator: "\n").write(to: URL(fileURLWithPath: "/tmp/ride-review-status.txt"), atomically: true, encoding: .utf8)
    }
}
