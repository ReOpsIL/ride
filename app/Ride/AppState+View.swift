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

    func showNotice(_ text: String, seconds: Double = 6, action: (title: String, run: () -> Void)? = nil) {
        notice = text
        noticeAction = action
        noticeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.notice = nil
            self?.noticeAction = nil
        }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func checkTools() {
        guard prefs.askMissingTools, !DemoLaunch.isDemo else {
            return
        }
        ToolsModel.shared.refresh { [weak self] in
            guard let self else {
                return
            }
            let missing = ToolsModel.shared.missing.map(\.info.name)
            guard !missing.isEmpty else {
                return
            }
            let names = missing.joined(separator: ", ")
            showNotice("Missing tools: \(names)", seconds: 20, action: ("Install…", { [weak self] in
                self?.notice = nil
                self?.showToolsSheet = true
            }))
        }
    }

    func toggleOutlinePanel() {
        updatePrefs { $0.outlinePanel.toggle() }
    }
}
