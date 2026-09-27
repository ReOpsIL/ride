import SwiftUI

struct ProblemsPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var check = CheckService.shared
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject private var model = ProblemsPanelModel.shared

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "exclamationmark.triangle", title: "Problems", badges: badges) {
                IconButton(symbol: "xmark.octagon", help: "Show errors", tint: model.filter.showErrors ? ts.ui.error : nil, active: model.filter.showErrors) {
                    model.filter.showErrors.toggle()
                }
                IconButton(symbol: "exclamationmark.triangle", help: "Show warnings", tint: model.filter.showWarnings ? ts.ui.warning : nil, active: model.filter.showWarnings) {
                    model.filter.showWarnings.toggle()
                }
                IconButton(symbol: "arrow.clockwise", help: Shortcuts.help("Check", "Build › Check")) {
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

    private var visible: [StoredDiagnostic] {
        model.filter.visible(check.snapshot)
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
            out.append(PanelBadge(id: "e", text: Plural.count(check.errorCount, "error"), tint: ts.ui.error))
        }
        if check.warningCount > 0 {
            out.append(PanelBadge(id: "w", text: Plural.count(check.warningCount, "warning"), tint: ts.ui.warning))
        }
        return out
    }

    @ViewBuilder
    private var content: some View {
        if visible.isEmpty, let failure = check.failure {
            Text(check.stderrTail.isEmpty ? failure : check.stderrTail.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(8)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else if visible.isEmpty {
            Text(check.hasRun ? "No problems" : Shortcuts.help("Run Check", "Build › Check") + " to see problems")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visible, id: \.self) { diag in
                        ProblemRow(
                            diag: diag,
                            location: location(diag),
                            selected: model.selected == diag,
                            fix: { state.applyDiagnosticFix(diag, fix: $0) }
                        ) {
                            state.openDiagnostic(diag)
                        }
                    }
                }
                .padding(.vertical, Tokens.Space.xs)
            }
        }
    }

    private func location(_ diag: StoredDiagnostic) -> String {
        let url = URL(fileURLWithPath: diag.path)
        let rel = state.workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: url) } ?? url.lastPathComponent
        return "\(rel):\(diag.line):\(diag.column)"
    }
}
