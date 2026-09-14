import SwiftUI

struct PaneTabStrips: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ts = ThemeStore.shared

    var body: some View {
        GeometryReader { geo in
            let editorWidth = max(0, geo.size.width - sidePanelsWidth)
            HStack(spacing: 0) {
                ForEach(state.paneLayout.panes) { pane in
                    TabStrip(pane: pane)
                        .frame(width: width(of: pane, editorWidth: editorWidth))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: Tokens.Size.tab)
        .background(ts.ui.bgRaised)
    }

    private var sidePanelsWidth: CGFloat {
        var width: CGFloat = 0
        if state.previewVisible {
            width += state.prefs.previewWidth + SplitHandle.width
        }
        if state.prefs.outlinePanel {
            width += state.prefs.outlineWidth + SplitHandle.width
        }
        return width
    }

    private func width(of pane: Pane, editorWidth: CGFloat) -> CGFloat {
        let panes = state.paneLayout.panes
        guard panes.count >= 2 else {
            return editorWidth
        }
        let ratio = state.splitLayout.ratio
        return pane.id == panes[0].id ? editorWidth * ratio : editorWidth * (1 - ratio)
    }
}
