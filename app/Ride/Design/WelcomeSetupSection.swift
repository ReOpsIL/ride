import SwiftUI

struct WelcomeSetupSection: View {
    @ObservedObject private var model = ToolsModel.shared
    @ObservedObject private var ts = ThemeStore.shared
    @State private var developerMode = false

    private var rows: [SetupRow] {
        SetupRows.rows(tools: model.rows.map(\.setup), developerMode: developerMode)
    }

    var body: some View {
        Group {
            if !SetupRows.allGreen(rows) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("Set up")
                        .font(Tokens.ui(11, weight: .semibold))
                        .foregroundStyle(ts.ui.textTertiary)
                    ForEach(rows) { row in
                        SetupRowView(row: row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            model.refresh()
            // DeveloperMode.isEnabled runs DevToolsSecurity and waits for it, which spins the
            // run loop; never do that while SwiftUI is building the view.
            DispatchQueue.global(qos: .utility).async {
                let enabled = DeveloperMode.isEnabled
                DispatchQueue.main.async {
                    developerMode = enabled
                }
            }
        }
    }
}

private struct SetupRowView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared
    let row: SetupRow

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: row.installed ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(row.installed ? ts.ui.accent : ts.ui.warning)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(Tokens.ui(12, weight: .medium))
                    .foregroundStyle(ts.ui.textPrimary)
                Text(row.installed ? row.purpose : (row.command ?? row.purpose))
                    .font(row.installed ? Tokens.ui(11) : Tokens.mono(10))
                    .foregroundStyle(ts.ui.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Tokens.Space.m)
            action
        }
        .padding(.horizontal, Tokens.Space.m)
        .frame(height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var action: some View {
        if row.installed {
            EmptyView()
        } else if let command = row.command, row.manual {
            CopyCommandButton(command: command)
        } else if row.command != nil {
            Button("Install") {
                ToolsModel.shared.present(row.name)
                state.showToolsSheet = true
            }
            .controlSize(.small)
            .font(Tokens.ui(11))
        }
    }
}
