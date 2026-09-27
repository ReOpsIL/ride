import Foundation

extension AppState {
    @discardableResult
    func toggleOverlay(_ pressed: Overlay) -> Bool {
        let next = Overlay.toggled(overlay, pressing: pressed)
        closeOverlays()
        overlay = next
        return next != nil
    }

    func closeOverlays() {
        overlay = nil
        showFind = false
        projectFind.showPreview = false
    }

    var showQuickOpen: Bool {
        get { overlay == .quickOpen }
        set { overlay = Overlay.setting(overlay, .quickOpen, shown: newValue) }
    }

    var showRecentFiles: Bool {
        get { overlay == .recentFiles }
        set { overlay = Overlay.setting(overlay, .recentFiles, shown: newValue) }
    }

    var showGoToLine: Bool {
        get { overlay == .goToLine }
        set { overlay = Overlay.setting(overlay, .goToLine, shown: newValue) }
    }

    var showSymbolInFile: Bool {
        get { overlay == .symbolInFile }
        set { overlay = Overlay.setting(overlay, .symbolInFile, shown: newValue) }
    }

    var showSymbolPicker: Bool {
        get { overlay == .symbolInProject }
        set { overlay = Overlay.setting(overlay, .symbolInProject, shown: newValue) }
    }

    var showProjectFind: Bool {
        get { overlay == .projectFind }
        set { overlay = Overlay.setting(overlay, .projectFind, shown: newValue) }
    }
}
