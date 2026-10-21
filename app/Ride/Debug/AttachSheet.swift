import SwiftUI

struct AttachSheet: View {
    @ObservedObject var model: AttachModel
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Attach to Process")
                .font(Tokens.ui(15, weight: .semibold))
            Picker("", selection: $model.mode) {
                ForEach(AttachMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch model.mode {
            case .process:
                processPicker
            case .waitFor:
                waitForm
            }
            HStack {
                if model.mode == .process {
                    Button("Refresh") { model.refresh() }
                        .disabled(model.loading)
                }
                Spacer()
                Button("Cancel") { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Attach") { model.attach() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.choice == nil)
            }
        }
        .padding(Tokens.Space.xxl)
        .frame(width: 560)
        .background(ts.ui.bgBase)
    }

    private var processPicker: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            TextField("Filter by name or PID", text: $model.query)
                .font(Tokens.mono(11))
                .textFieldStyle(.roundedBorder)
            List(model.matching, selection: $model.selection) { row in
                AttachProcessRow(row: row)
                    .tag(row.pid)
            }
            .frame(height: 280)
            .overlay {
                if model.loading && model.rows.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private var waitForm: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            TextField("Program name or path", text: $model.waitName)
                .font(Tokens.mono(11))
                .textFieldStyle(.roundedBorder)
            Text("Ride attaches to the next process with this name, for example a child started by fork(). Processes already running are skipped.")
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AttachProcessRow: View {
    let row: ProcessRow
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Text(row.name)
                .font(Tokens.ui(12))
                .foregroundStyle(ts.ui.textPrimary)
                .lineLimit(1)
            Spacer()
            Text("pid \(row.pid)  parent \(row.parent)")
                .font(Tokens.mono(11))
                .foregroundStyle(ts.ui.textSecondary)
        }
        .help(row.path)
    }
}
