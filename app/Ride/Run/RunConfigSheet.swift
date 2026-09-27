import SwiftUI

struct RunConfigSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var editor: RunConfigEditor
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Run Configuration")
                .font(Tokens.ui(15, weight: .semibold))
            Text(editor.target.isEmpty ? "No target" : editor.target)
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textSecondary)
            fields
            RunConfigEnvTable(editor: editor)
            HStack {
                Spacer()
                Button("Cancel") { state.cancelRunConfig() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { state.saveRunConfig() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 560)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            LabeledContent("Build Arguments") {
                TextField("", text: $editor.draft.buildArgs)
                    .font(Tokens.mono(11))
            }
            LabeledContent("Program Arguments") {
                TextField("", text: $editor.draft.args)
                    .font(Tokens.mono(11))
            }
            LabeledContent("Working Directory") {
                TextField("", text: $editor.draft.workingDir)
                    .font(Tokens.mono(11))
            }
            Toggle("RUST_BACKTRACE=1", isOn: $editor.draft.rustBacktrace)
                .font(Tokens.ui(11))
            sanitizerToggles
        }
    }

    @ViewBuilder private var sanitizerToggles: some View {
        if !editor.sanitizers.isEmpty {
            HStack(spacing: Tokens.Space.l) {
                ForEach(editor.sanitizers, id: \.self) { sanitizer in
                    Toggle(sanitizer.rawValue, isOn: binding(for: sanitizer))
                        .font(Tokens.ui(11))
                }
            }
        }
        if editor.requiresNightly {
            Text("Cargo sanitizers need a nightly toolchain.")
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.warning)
        }
    }

    private func binding(for sanitizer: Sanitizer) -> Binding<Bool> {
        Binding(get: { editor.isOn(sanitizer) }, set: { editor.set(sanitizer, on: $0) })
    }
}

struct RunConfigEnvTable: View {
    @ObservedObject var editor: RunConfigEditor
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack {
                Text("Environment")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                Spacer()
                Button("Add") { editor.addEnvRow() }
                    .controlSize(.small)
            }
            ForEach($editor.draft.env) { $row in
                HStack(spacing: Tokens.Space.s) {
                    TextField("KEY", text: $row.key)
                        .font(Tokens.mono(11))
                    TextField("value", text: $row.value)
                        .font(Tokens.mono(11))
                    Button {
                        editor.removeEnvRow(id: row.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
