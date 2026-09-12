import SwiftUI

struct TestsPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var store: TestRunStore

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "checkmark.diamond", title: "Tests", badges: badges) {
                TestFilterField(text: $store.filter)
                IconButton(symbol: "arrow.clockwise", help: "Rerun Failed") {
                    state.rerunFailedTests()
                }
                .disabled(store.running || !state.canRerunFailedTests)
                IconButton(symbol: "trash", help: "Clear") {
                    store.clear()
                }
                IconButton(symbol: "xmark", help: "Hide Tests", size: 9) {
                    state.showTests = false
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        var out: [PanelBadge] = []
        if let command = store.command {
            out.append(PanelBadge(id: "cmd", text: command, tint: nil))
        }
        if store.tree.passed > 0 {
            out.append(PanelBadge(id: "p", text: "\(store.tree.passed) passed", tint: ts.ui.success))
        }
        if store.tree.failed > 0 {
            out.append(PanelBadge(id: "f", text: "\(store.tree.failed) failed", tint: ts.ui.error))
        }
        if store.tree.ignored > 0 {
            out.append(PanelBadge(id: "i", text: "\(store.tree.ignored) ignored", tint: nil))
        }
        if store.running {
            out.append(PanelBadge(id: "run", text: "running…", tint: ts.ui.accent))
        } else if let status = store.status {
            out.append(PanelBadge(id: "s", text: status, tint: status == "passed" ? ts.ui.success : ts.ui.error))
        }
        return out
    }

    @ViewBuilder
    private var content: some View {
        let groups = store.tree.groups(filter: store.filter)
        if groups.isEmpty {
            Text(store.tree.rows.isEmpty ? "Run Tests (⇧⌘R) to see results" : "No test matches the filter")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else {
            HSplitView {
                TestTreeList(groups: groups, selected: $store.selected)
                    .frame(minWidth: 220, idealWidth: 360, maxWidth: .infinity)
                TestOutputView(text: selectedOutput)
                    .frame(minWidth: 200, maxWidth: .infinity)
            }
        }
    }

    private var selectedOutput: String {
        guard let id = store.selected, let row = store.tree.row(id: id) else {
            return ""
        }
        return row.output
    }
}

struct TestFilterField: View {
    @Binding var text: String
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        TextField("Filter", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(Tokens.ui(11))
            .frame(width: 140)
    }
}

struct TestOutputView: View {
    let text: String
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "No output" : text)
                .font(Tokens.mono(11))
                .foregroundStyle(text.isEmpty ? ts.ui.textTertiary : ts.ui.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
