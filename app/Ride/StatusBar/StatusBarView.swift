import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var engine = RideEngineClient.shared

    var body: some View {
        HStack(spacing: 10) {
            Text("\(state.cursorLine):\(state.cursorColumn)")
            Text(state.relativePath)
            if let error = state.formatError {
                Text("rustfmt: \(error)")
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
                    .help(error)
            }
            Spacer()
            CheckStatusView()
            Text(state.windowTitle)
            Text(engine.indexLabel)
                .lineLimit(1)
                .help(engine.indexDetail ?? "")
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
