import SwiftUI

struct ToolsInstallView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var model = ToolsModel.shared
    @ObservedObject private var ts = ThemeStore.shared
    @State private var dontAsk = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Tools")
                .font(Tokens.ui(15, weight: .semibold))
            Text(model.missing.isEmpty ? "Every tool Ride uses is installed." : "These tools are missing. Select the ones to install; commands run in your login shell.")
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textSecondary)
            list
            if !model.log.isEmpty {
                ScrollView {
                    Text(model.log)
                        .font(Tokens.mono(11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 140)
                .padding(Tokens.Space.s)
                .background(ts.ui.bgBase, in: RoundedRectangle(cornerRadius: Tokens.Radius.m))
            }
            HStack {
                Toggle("Don't ask again at launch", isOn: $dontAsk)
                    .font(Tokens.ui(11))
                Spacer()
                Button("Close") { close() }
                    .keyboardShortcut(.cancelAction)
                Button(model.installing ? "Installing…" : "Install Selected") { model.installSelected() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.installing || !model.rows.contains { $0.missing && $0.selected && $0.info.install != nil })
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 560)
        .onAppear {
            dontAsk = !state.prefs.askMissingTools
            model.refresh()
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            ForEach($model.rows) { $row in
                HStack(alignment: .top, spacing: Tokens.Space.m) {
                    if row.missing, row.info.install != nil {
                        Toggle("", isOn: $row.selected)
                            .labelsHidden()
                            .disabled(model.installing)
                    } else {
                        Image(systemName: row.missing ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundStyle(row.missing ? ts.ui.warning : ts.ui.accent)
                            .frame(width: 18)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Tokens.Space.s) {
                            Text(row.info.name).font(Tokens.mono(12, weight: .semibold))
                            Text(row.info.purpose).font(Tokens.ui(11)).foregroundStyle(ts.ui.textSecondary)
                            if let result = row.result {
                                Text(result).font(Tokens.ui(10)).foregroundStyle(result == "installed" ? ts.ui.accent : ts.ui.error)
                            }
                        }
                        Text(row.missing ? (row.info.install ?? row.info.hint) : (row.info.path ?? ""))
                            .font(Tokens.mono(10))
                            .foregroundStyle(ts.ui.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }

    private func close() {
        if state.prefs.askMissingTools == dontAsk {
            state.updatePrefs { $0.askMissingTools = !dontAsk }
        }
        state.showToolsSheet = false
    }
}
