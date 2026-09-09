import SwiftUI

struct TabStrip: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(state.buffers) { buffer in
                    TabItem(buffer: buffer, selected: buffer.id == state.activeID)
                }
            }
        }
        .frame(height: Tokens.Size.tab)
        .frame(maxWidth: .infinity)
        .background(ts.ui.bgRaised)
        .overlay(alignment: .trailing) {
            LinearGradient(colors: [ts.ui.bgRaised.opacity(0), ts.ui.bgRaised], startPoint: .leading, endPoint: .trailing)
                .frame(width: 20)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
        .overlay(alignment: .top) {
            ts.ui.border.frame(height: Tokens.Size.hairline)
        }
    }
}
