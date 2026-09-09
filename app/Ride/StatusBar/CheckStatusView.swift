import SwiftUI

struct CheckStatusView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var check = CheckService.shared

    var body: some View {
        HStack(spacing: 4) {
            if check.running {
                ProgressView()
                    .controlSize(.mini)
                Text("checking…")
            } else if check.hasRun {
                Text(CheckSummary.text(errors: check.errorCount, warnings: check.warningCount, failure: check.failure))
                    .foregroundStyle(check.errorCount > 0 ? Color.red : Color.secondary)
            }
        }
        .lineLimit(1)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleProblems()
        }
        .help(check.failure ?? "")
    }
}

enum CheckSummary {
    static func text(errors: Int, warnings: Int, failure: String?) -> String {
        if errors == 0, warnings == 0 {
            return failure == nil ? "check ok" : "check failed"
        }
        return "\(errors) errors, \(warnings) warnings"
    }
}
