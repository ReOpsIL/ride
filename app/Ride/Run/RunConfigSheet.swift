import SwiftUI

struct RunConfigSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    @State private var draft = RunConfigDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Run Configuration")
                .font(Tokens.ui(15, weight: .semibold))
            Text(state.runTarget?.name ?? "No target")
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textSecondary)
            fields
            RunConfigEnvTable(rows: $draft.env)
            HStack {
                Spacer()
                Button("Cancel") { state.showRunConfigSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 560)
        .onAppear { draft = RunConfigDraft(state.runConfig) }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            LabeledContent("Arguments") {
                TextField("", text: $draft.args)
                    .font(Tokens.mono(11))
            }
            LabeledContent("Working Directory") {
                TextField("", text: $draft.workingDir)
                    .font(Tokens.mono(11))
            }
            Toggle("RUST_BACKTRACE=1", isOn: $draft.rustBacktrace)
                .font(Tokens.ui(11))
            HStack(spacing: Tokens.Space.l) {
                ForEach(Sanitizer.allCases, id: \.self) { sanitizer in
                    Toggle(sanitizer.rawValue, isOn: binding(for: sanitizer))
                        .font(Tokens.ui(11))
                }
            }
            if draft.requiresNightly(kind: state.projectModel.runKind) {
                Text("Cargo sanitizers need a nightly toolchain.")
                    .font(Tokens.ui(11))
                    .foregroundStyle(ts.ui.warning)
            }
        }
    }

    private func binding(for sanitizer: Sanitizer) -> Binding<Bool> {
        Binding(
            get: { draft.sanitizers.contains(sanitizer) },
            set: { on in
                if on {
                    draft.sanitizers.insert(sanitizer)
                } else {
                    draft.sanitizers.remove(sanitizer)
                }
            }
        )
    }

    private func save() {
        state.saveRunConfig(draft.config(target: state.runTarget?.name ?? ""))
        state.showRunConfigSheet = false
    }
}

struct RunConfigEnvTable: View {
    @Binding var rows: [RunConfigEnvRow]
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack {
                Text("Environment")
                    .font(Tokens.ui(11, weight: .semibold))
                    .foregroundStyle(ts.ui.textTertiary)
                Spacer()
                Button("Add") { rows.append(RunConfigEnvRow()) }
                    .controlSize(.small)
            }
            ForEach($rows) { $row in
                HStack(spacing: Tokens.Space.s) {
                    TextField("KEY", text: $row.key)
                        .font(Tokens.mono(11))
                    TextField("value", text: $row.value)
                        .font(Tokens.mono(11))
                    Button {
                        rows.removeAll { $0.id == row.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
