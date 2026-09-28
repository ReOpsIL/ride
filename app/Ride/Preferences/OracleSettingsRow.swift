import SwiftUI

struct OracleSettingsRow: View {
    let bind: PreferenceBindings
    @ObservedObject private var client = RideEngineClient.shared

    var body: some View {
        Toggle(isOn: bind.bool(\.semanticCompletion)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Type-aware completion (rust-analyzer, clangd)")
                Text(Self.caption(client.oracleStatus))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func caption(_ status: OracleStatus) -> String {
        switch status.state {
        case .off:
            return "Off: completion uses Ride's own index and type guesses"
        case .idle:
            return "Starts with the first completion in a Rust, C or C++ file"
        case .starting:
            return "\(status.message ?? "The language server") is loading the project"
        case .ready:
            return "\(status.message ?? "The language server") is ready"
        case .unavailable, .failed:
            return status.message ?? "The language server is not running"
        }
    }
}
