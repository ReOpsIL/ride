import Foundation

extension AppState {
    static let zoomRange = 10...24

    func zoom(_ delta: Int) {
        updatePrefs { prefs in
            prefs.fontSize = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, prefs.fontSize + delta))
        }
    }

    func resetZoom() {
        updatePrefs { $0.fontSize = Preferences.defaults.fontSize }
    }

    func toggleSoftWrap() {
        updatePrefs { $0.softWrap.toggle() }
    }

    func toggleWhitespace() {
        updatePrefs { $0.visibleWhitespace.toggle() }
    }

    func toggleIndentGuides() {
        updatePrefs { $0.indentGuides.toggle() }
    }

    func showNotice(_ text: String, seconds: Double = 6) {
        notice = text
        noticeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.notice = nil
        }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func toggleOutlinePanel() {
        updatePrefs { $0.outlinePanel.toggle() }
    }
}
