import SwiftUI

struct CheckStatusView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var check = CheckService.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            if check.running {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking…")
            } else if check.hasRun {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(CheckSummary.text(errors: check.errorCount, warnings: check.warningCount, failure: check.failure))
            }
        }
        .font(Tokens.ui(11))
        .foregroundStyle(tint)
        .lineLimit(1)
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: 18)
        .background(check.hasRun && check.errorCount > 0 ? ts.ui.error.opacity(0.15) : Color.clear, in: Capsule())
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleProblems()
        }
        .help(check.failure ?? "Problems (⇧⌘M)")
    }

    private var symbol: String {
        if check.errorCount > 0 {
            return "xmark.octagon.fill"
        }
        if check.warningCount > 0 {
            return "exclamationmark.triangle.fill"
        }
        return check.failure == nil ? "checkmark.circle.fill" : "xmark.circle"
    }

    private var tint: Color {
        if check.errorCount > 0 {
            return ts.ui.error
        }
        if check.warningCount > 0 {
            return ts.ui.warning
        }
        return check.hasRun && check.failure == nil ? ts.ui.success : ts.ui.textSecondary
    }
}

enum CheckSummary {
    static func text(errors: Int, warnings: Int, failure: String?) -> String {
        if errors == 0, warnings == 0 {
            return failure == nil ? "Check ok" : "Check failed"
        }
        var parts: [String] = []
        if errors > 0 {
            parts.append("\(errors) error\(errors == 1 ? "" : "s")")
        }
        if warnings > 0 {
            parts.append("\(warnings) warning\(warnings == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}
