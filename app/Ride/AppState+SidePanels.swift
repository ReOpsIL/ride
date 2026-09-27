import CoreGraphics

extension AppState {
    var sidePanelsWidth: CGFloat {
        var width: CGFloat = 0
        if previewVisible {
            width += prefs.previewWidth + SplitHandle.width
        }
        if prefs.outlinePanel {
            width += prefs.outlineWidth + SplitHandle.width
        }
        if showHierarchy {
            width += prefs.hierarchyWidth + SplitHandle.width
        }
        return width
    }
}
