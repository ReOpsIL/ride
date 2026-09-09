import SwiftUI

struct ProblemsPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var check = CheckService.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "exclamationmark.triangle", title: "Problems", badges: badges) {
                IconButton(symbol: "arrow.clockwise", help: "Check (⌘B)") {
                    state.runCheck()
                }
                IconButton(symbol: "xmark", help: "Hide Problems", size: 9) {
                    state.showProblems = false
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        if check.running {
            return [PanelBadge(id: "run", text: "checking…", tint: nil)]
        }
        if let failure = check.failure {
            return [PanelBadge(id: "fail", text: failure, tint: ts.ui.error)]
        }
        var out: [PanelBadge] = []
        if check.errorCount > 0 {
            out.append(PanelBadge(id: "e", text: "\(check.errorCount) errors", tint: ts.ui.error))
        }
        if check.warningCount > 0 {
            out.append(PanelBadge(id: "w", text: "\(check.warningCount) warnings", tint: ts.ui.warning))
        }
        return out
    }

    @ViewBuilder
    private var content: some View {
        if check.diagnostics.isEmpty {
            Text(check.hasRun ? "No problems" : "Run Check (⌘B) to see problems")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(check.diagnostics.enumerated()), id: \.offset) { _, diag in
                        ProblemRow(diag: diag, location: location(diag))
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }

    private func location(_ diag: Diagnostic) -> String {
        let url = URL(fileURLWithPath: diag.path)
        let rel = state.workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: url) } ?? url.lastPathComponent
        return "\(rel):\(diag.line):\(diag.column)"
    }
}

struct ProblemRow: View {
    let diag: Diagnostic
    let location: String
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: diag.level == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(diag.level == .error ? ts.ui.error : ts.ui.warning)
                .frame(width: 14)
            Text(diag.message)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            if let code = diag.code {
                Text(code)
                    .font(Tokens.mono(10))
                    .foregroundStyle(ts.ui.textTertiary)
            }
            Spacer(minLength: Tokens.Space.m)
            Text(location)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.sidebarRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? ts.ui.bgHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            state.openDiagnostic(diag)
        }
    }
}
