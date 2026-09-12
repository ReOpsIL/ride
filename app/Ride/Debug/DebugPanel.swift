import SwiftUI

struct DebugPanel: View {
    @ObservedObject var model: DebugPanelModel
    @ObservedObject private var debug = DebugController.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "ladybug", title: "Debug", badges: badges) {
                IconButton(symbol: "plus.magnifyingglass", help: "Evaluate Expression (⌥F8)") {
                    model.showEvaluate = true
                }
                .disabled(!model.isStopped)
                IconButton(symbol: "xmark", help: "Hide Debug", size: 9) {
                    model.visible = false
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
        .sheet(isPresented: $model.showEvaluate) {
            DebugEvaluateSheet(model: model)
        }
    }

    private var badges: [PanelBadge] {
        switch debug.state {
        case .idle:
            return []
        case .launching:
            return [PanelBadge(id: "s", text: "launching…", tint: ts.ui.accent)]
        case .running:
            return [PanelBadge(id: "s", text: "running", tint: ts.ui.accent)]
        case let .stopped(_, reason):
            return [PanelBadge(id: "s", text: "stopped · \(reason)", tint: ts.ui.warning)]
        case let .exited(code):
            return [PanelBadge(id: "s", text: "exited \(code)", tint: code == 0 ? ts.ui.success : ts.ui.error)]
        case .terminated:
            return [PanelBadge(id: "s", text: "terminated", tint: nil)]
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.isStopped {
            Text(debug.isActive ? "Running — the panel fills in at the next stop" : "Debug (⌃⌘R) to inspect threads, frames and variables")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Tokens.Space.l)
        } else {
            HSplitView {
                DebugFramesList(model: model)
                    .frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity)
                DebugVariablesList(model: model)
                    .frame(minWidth: 220, maxWidth: .infinity)
                DebugWatchesList(model: model)
                    .frame(minWidth: 180, idealWidth: 240, maxWidth: .infinity)
            }
        }
    }
}

struct DebugEvaluateSheet: View {
    @ObservedObject var model: DebugPanelModel
    @ObservedObject private var ts = ThemeStore.shared
    @State private var expression = ""
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Evaluate Expression")
                .font(Tokens.ui(13, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            TextField("expression", text: $expression)
                .font(Tokens.mono(12))
                .textFieldStyle(.roundedBorder)
                .onSubmit(evaluate)
            ScrollView {
                Text(result)
                    .font(Tokens.mono(11))
                    .foregroundStyle(ts.ui.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: 80)
            HStack {
                Button("Watch") {
                    model.addWatch(expression)
                }
                .disabled(expression.isEmpty)
                Spacer()
                Button("Evaluate", action: evaluate)
                    .keyboardShortcut(.defaultAction)
                Button("Close") {
                    model.showEvaluate = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Tokens.Space.l)
        .frame(width: 460)
        .background(ts.ui.bgBase)
    }

    private func evaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        let row = model.evaluate(trimmed, context: .repl)
        result = row.typeName.map { "\(row.value)  ·  \($0)" } ?? row.value
    }
}
