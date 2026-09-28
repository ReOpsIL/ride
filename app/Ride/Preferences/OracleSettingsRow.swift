import SwiftUI

struct OracleSettingsRow: View {
    let bind: PreferenceBindings
    @ObservedObject private var client = RideEngineClient.shared

    var body: some View {
        Toggle(isOn: bind.bool(\.semanticCompletion)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Type-aware Rust completion (rust-analyzer)")
                Text(Self.caption(client.oracleStatus))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func caption(_ status: OracleStatus) -> String {
        switch status.state {
        case .off:
            return "Off: member lists use Ride's own type guesses"
        case .idle:
            return "Starts with the first member completion in a Cargo project"
        case .starting:
            return "rust-analyzer is loading the workspace"
        case .ready:
            return "rust-analyzer is ready"
        case .unavailable, .failed:
            return status.message ?? "rust-analyzer is not running"
        }
    }
}
