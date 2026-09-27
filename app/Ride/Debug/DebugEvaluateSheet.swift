import SwiftUI

struct DebugEvaluateSheet: View {
    @ObservedObject var model: DebugPanelModel
    @ObservedObject var evaluation: DebugEvaluation
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Evaluate Expression")
                .font(Tokens.ui(13, weight: .semibold))
                .foregroundStyle(ts.ui.textPrimary)
            TextField("expression", text: $evaluation.expression)
                .font(Tokens.mono(12))
                .textFieldStyle(.roundedBorder)
                .onSubmit { evaluation.evaluate(in: model) }
            ScrollView {
                Text(evaluation.result)
                    .font(Tokens.mono(11))
                    .foregroundStyle(evaluation.failed ? ts.ui.error : ts.ui.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: 80)
            HStack {
                Button("Watch") { evaluation.watch(in: model) }
                    .disabled(!evaluation.canSubmit)
                Spacer()
                Button("Evaluate") { evaluation.evaluate(in: model) }
                    .keyboardShortcut(.defaultAction)
                Button("Close") { evaluation.close(model) }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Tokens.Space.l)
        .frame(width: 460)
        .background(ts.ui.bgBase)
    }
}
