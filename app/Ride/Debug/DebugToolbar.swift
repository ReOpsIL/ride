import SwiftUI

struct DebugToolbar: View {
    let state: AppState
    @ObservedObject var menu: MenuModel
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            ForEach(Array(DebugAction.groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    ts.ui.border.frame(width: Tokens.Size.hairline, height: 14)
                        .padding(.horizontal, Tokens.Space.xs)
                }
                ForEach(group) { action in
                    button(action)
                }
            }
        }
    }

    private func button(_ action: DebugAction) -> some View {
        let enabled = action.isEnabled(menu.debugGates)
        return IconButton(symbol: action.symbol, help: action.help, tint: enabled ? tint(action) : nil) {
            action.perform(state)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func tint(_ action: DebugAction) -> Color? {
        switch action {
        case .resume: return ts.ui.success
        case .stop: return ts.ui.error
        default: return nil
        }
    }
}
