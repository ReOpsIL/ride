import SwiftUI

struct ProblemsPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var check = CheckService.shared
    @ObservedObject private var ts = ThemeStore.shared
    @State private var showErrors = true
    @State private var showWarnings = true
    @State private var selected: Int?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "exclamationmark.triangle", title: "Problems", badges: badges) {
                IconButton(symbol: "xmark.octagon", help: "Show errors", tint: showErrors ? ts.ui.error : nil, active: showErrors) {
                    showErrors.toggle()
                }
                IconButton(symbol: "exclamationmark.triangle", help: "Show warnings", tint: showWarnings ? ts.ui.warning : nil, active: showWarnings) {
                    showWarnings.toggle()
                }
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

    private var visible: [Diagnostic] {
        check.diagnostics.filter { ($0.level == .error && showErrors) || ($0.level != .error && showWarnings) }
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
        if visible.isEmpty {
            Text(check.hasRun ? "No problems" : "Run Check (⌘B) to see problems")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { index, diag in
                        ProblemRow(diag: diag, location: location(diag), selected: selected == index) {
                            selected = index
                            state.openDiagnostic(diag)
                        }
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
    let selected: Bool
    let action: () -> Void
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
            Text(location)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textTertiary)
                .lineLimit(1)
            if let code = diag.code {
                Text(code)
                    .font(Tokens.mono(10))
                    .foregroundStyle(ts.ui.textTertiary)
                    .padding(.horizontal, Tokens.Space.xs)
                    .background(ts.ui.bgHover, in: RoundedRectangle(cornerRadius: Tokens.Radius.s))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(height: Tokens.Size.sidebarRow)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? ts.ui.bgSelection : (hovering ? ts.ui.bgHover : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }
}
