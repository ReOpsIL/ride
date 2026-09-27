import Foundation

extension AppState {

    func zoom(_ delta: Int) {
        updatePrefs { prefs in
            prefs.fontSize = min(Preferences.fontSizes.upperBound, max(Preferences.fontSizes.lowerBound, prefs.fontSize + delta))
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

    func checkTools() {
        guard prefs.askMissingTools else {
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
