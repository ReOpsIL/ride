import SwiftUI

struct IndexStatusView: View {
    @ObservedObject private var engine = RideEngineClient.shared
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            if let progress = engine.indexProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(ts.ui.accent)
                    .frame(width: 60)
            } else {
                Image(systemName: engine.rustSrcAvailable ? "shippingbox" : "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(engine.rustSrcAvailable ? ts.ui.textSecondary : ts.ui.warning)
            }
            Text(engine.indexLabel)
                .font(Tokens.ui(11))
                .foregroundStyle(ts.ui.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(height: 18)
        .help(engine.indexDetail ?? engine.indexLabel)
    }
}
