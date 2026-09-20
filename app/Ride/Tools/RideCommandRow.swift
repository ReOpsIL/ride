import SwiftUI

struct RideCommandRow: View {
    @ObservedObject private var command = RideCommand.shared

    var body: some View {
        LabeledContent("Install `ride` command") {
            switch command.state {
            case .installed:
                Label("Installed", systemImage: "checkmark.circle")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.secondary)
            case .missing:
                Button("Install", action: command.install)
                    .disabled(command.busy)
            case .failed(let message):
                HStack(spacing: Tokens.Space.s) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button("Retry", action: command.install)
                        .disabled(command.busy)
                }
            }
        }
        .onAppear(perform: command.refresh)
    }
}
