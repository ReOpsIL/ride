import SwiftUI

struct RunOutputPanel: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @ObservedObject var output: RunOutput

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "play.rectangle", title: "Run", badges: badges) {
                IconButton(symbol: "stop.fill", help: "Stop", tint: output.isRunning ? ts.ui.error : nil) {
                    output.stop()
                }
                .disabled(!output.isRunning)
                IconButton(symbol: "arrow.clockwise", help: "Rerun") {
                    state.rerunOutput()
                }
                .disabled(output.isRunning || !output.canRerun)
                IconButton(symbol: "trash", help: "Clear") {
                    output.clear()
                }
                IconButton(symbol: "xmark", help: "Hide Run", size: 9) {
                    state.showRunOutput = false
                }
            }
            RunOutputText(
                buffer: output.buffer,
                theme: ts.theme,
                fontSize: CGFloat(state.prefs.fontSize),
                onLink: { link in state.openConsoleLink(link) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        var out: [PanelBadge] = []
        if let command = output.command {
            out.append(PanelBadge(id: "cmd", text: command, tint: nil))
        }
        if output.isRunning {
            out.append(PanelBadge(id: "run", text: "running…", tint: ts.ui.accent))
        } else if let status = output.status {
            out.append(PanelBadge(id: "status", text: status, tint: status == "exit 0" ? ts.ui.success : ts.ui.error))
        }
        return out
    }
}
