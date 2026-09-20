import AppKit

extension AppState {
    func checkCrashReports() {
        guard !DemoLaunch.isDemo else {
            return
        }
        let store = ReportStore(directory: ReportPaths.directory)
        store.prune()
        let fresh = store.new(since: prefs.reportsAcknowledged)
        guard !fresh.isEmpty else {
            return
        }
        let report = store.text(of: fresh)
        showNotice(
            ReportStore.noticeText(for: fresh),
            seconds: 30,
            action: ("Copy Report", { ReportPasteboard.copy(report) }),
            onDismiss: { [weak self] in
                self?.acknowledgeReports()
            }
        )
    }

    func acknowledgeReports() {
        updatePrefs { $0.reportsAcknowledged = Date().timeIntervalSince1970 }
    }
}

enum ReportPasteboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
