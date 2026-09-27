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
            DebugEvaluateSheet(model: model, evaluation: DebugEvaluation.shared)
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
