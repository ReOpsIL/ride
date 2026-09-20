import SwiftUI

struct AIAskSheet: View {
    @ObservedObject var assistant: AIAssistant
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Ask AI")
                .font(.headline)
            TextEditor(text: $assistant.prompt)
                .font(Tokens.mono(12))
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.s).stroke(ts.ui.border))
            Picker("Context", selection: $assistant.level) {
                ForEach(AIContextLevel.allCases, id: \.rawValue) { level in
                    Text(level.title).tag(level.rawValue)
                }
            }
            Text(selectionNote)
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textSecondary)
            HStack {
                Spacer()
                Button("Cancel") { assistant.showPrompt = false }
                    .keyboardShortcut(.cancelAction)
                Button("Send") { assistant.send() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(assistant.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 540)
    }

    private var selectionNote: String {
        guard !assistant.selection.isEmpty else {
            return "No selection. The caret position and the chosen context are sent."
        }
        let lines = assistant.selection.components(separatedBy: "\n").count
        return "The selected \(Plural.count(lines, "line")) and the chosen context are sent with the request."
    }
}
