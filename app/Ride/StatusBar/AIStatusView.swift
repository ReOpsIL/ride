import SwiftUI

struct AIStatusView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var activity = AIActivity.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        if activity.busy > 0 {
            HStack(spacing: Tokens.Space.s) {
                ProgressView()
                    .controlSize(.small)
                Text("AI…")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.textSecondary)
            }
            .padding(.horizontal, Tokens.Space.s)
            .frame(height: 18)
            .help("Waiting for the AI provider")
        } else if let note = activity.note {
            StatusSegment(icon: "sparkles", text: note, help: "Last AI completion request")
        } else if state.prefs.aiComplete {
            StatusSegment(icon: "sparkles", text: "AI", help: "AI suggestions are on")
        }
    }
}
