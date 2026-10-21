import SwiftUI

struct RemoteProbeView: View {
    @ObservedObject var editor: RemoteEditor
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        switch editor.probe {
        case .idle:
            note("Test Remote signs in with these settings and checks Remote Root and the tools a build needs. Nothing is copied.")
        case .running:
            HStack(spacing: Tokens.Space.m) {
                ProgressView().controlSize(.small)
                note("Connecting…")
            }
        case let .rejected(message):
            RemoteCheckRow(title: "Cannot test", status: .fail, detail: message)
        case let .finished(checks, command):
            finished(checks, command: command)
        }
    }

    private func finished(_ checks: [RemoteCheck], command: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text(verdict(checks))
                .font(Tokens.ui(12, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                        RemoteCheckRow(title: check.title, status: check.status, detail: check.detail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            Text(command)
                .font(Tokens.mono(10))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(2)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .help(command)
        }
    }

    private func verdict(_ checks: [RemoteCheck]) -> String {
        if checks.contains(where: { $0.status == .fail }) {
            return "Not ready. Fix the items marked ✕."
        }
        if checks.contains(where: { $0.status == .warn }) {
            return "Ready, with warnings."
        }
        return "Ready for remote builds."
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Tokens.ui(11))
            .foregroundStyle(ts.ui.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct RemoteCheckRow: View {
    let title: String
    let status: RemoteCheckStatus
    let detail: String
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(title)
                    .font(Tokens.ui(11, weight: .semibold))
                Text(verbatim: detail)
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var symbol: String {
        switch status {
        case .pass: "checkmark.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .fail: "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .pass: ts.ui.success
        case .warn: ts.ui.warning
        case .fail: ts.ui.error
        }
    }
}
