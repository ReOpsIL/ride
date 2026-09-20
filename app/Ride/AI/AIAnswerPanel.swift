import SwiftUI

struct AIAnswerPanel: View {
    @ObservedObject var assistant: AIAssistant
    @ObservedObject private var activity = AIActivity.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(icon: "sparkles", title: "AI", badges: badges) {
                IconButton(symbol: "text.insert", help: "Insert code at caret") { assistant.insertAnswer() }
                    .disabled(assistant.answer.isEmpty)
                IconButton(symbol: "doc.on.doc", help: "Copy answer") { assistant.copyAnswer() }
                    .disabled(assistant.answer.isEmpty)
                IconButton(symbol: "arrow.uturn.backward", help: "Edit the request and ask again") { assistant.showPrompt = true }
                IconButton(symbol: "xmark", help: "Hide AI panel", size: 9) { assistant.showPanel = false }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.m) {
                    Text(assistant.question)
                        .font(Tokens.ui(11))
                        .foregroundStyle(ts.ui.textSecondary)
                    if let error = assistant.error {
                        Text(error)
                            .font(Tokens.ui(11))
                            .foregroundStyle(ts.ui.error)
                    }
                    Text(assistant.answer)
                        .font(Tokens.mono(11))
                        .foregroundStyle(ts.ui.textPrimary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Space.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ts.ui.bgBase)
    }

    private var badges: [PanelBadge] {
        activity.busy > 0 ? [PanelBadge(id: "busy", text: "thinking…", tint: nil)] : []
    }
}
