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

    func toggleLineNumbers() {
        updatePrefs { $0.lineNumbers.toggle() }
    }

    func toggleCodeVision() {
        updatePrefs { $0.codeVision.toggle() }
    }

    func showNotice(
        _ text: String,
        seconds: Double = 6,
        action: (title: String, run: () -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        noticeWork?.cancel()
        notice = text
        noticeAction = action
        noticeDismiss = onDismiss
        let work = DispatchWorkItem { [weak self] in
            self?.clearNotice()
        }
        noticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func dismissNotice() {
        let run = noticeDismiss
        clearNotice()
        run?()
    }

    func clearNotice() {
        noticeWork?.cancel()
        noticeWork = nil
        notice = nil
        noticeAction = nil
        noticeDismiss = nil
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
                self?.clearNotice()
                self?.showToolsSheet = true
            }))
        }
    }

    func toggleOutlinePanel() {
        updatePrefs { $0.outlinePanel.toggle() }
    }
}
