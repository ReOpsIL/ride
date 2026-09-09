import SwiftUI

struct ProblemsPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var check = CheckService.shared

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Text("Problems")
                    .font(.system(size: 11, weight: .semibold))
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    state.showProblems = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            Divider()
            content
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var summary: String {
        if check.running {
            return "checking…"
        }
        if let failure = check.failure {
            return failure
        }
        return "\(check.errorCount) errors, \(check.warningCount) warnings"
    }

    @ViewBuilder
    private var content: some View {
        if check.diagnostics.isEmpty {
            Text(check.hasRun ? "No problems" : "Run Check (⌘B) to see problems")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(check.diagnostics.enumerated()), id: \.offset) { _, diag in
                        row(diag)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func row(_ diag: Diagnostic) -> some View {
        HStack(spacing: 8) {
            Text(diag.level == .error ? "E" : "W")
                .fontWeight(.bold)
                .foregroundStyle(diag.level == .error ? Color.red : Color.yellow)
                .frame(width: 12)
            Text(location(diag))
                .foregroundStyle(.secondary)
            Text(diag.message)
                .lineLimit(1)
            if let code = diag.code {
                Text("[\(code)]")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            state.openDiagnostic(diag)
        }
    }

    private func location(_ diag: Diagnostic) -> String {
        let url = URL(fileURLWithPath: diag.path)
        let rel = state.workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: url) } ?? url.lastPathComponent
        return "\(rel):\(diag.line):\(diag.column)"
    }
}
