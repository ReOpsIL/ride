import AppKit

extension SelfTestSteps {
    static func formatOnSaveSteps(state: AppState, e: SelfTestEditor, bind: PreferenceBindings) -> [SelfTestStep] {
        let root = state.workspaceRoot ?? URL(fileURLWithPath: "/")
        let file = root.appendingPathComponent("src/ride_fmt_probe.rs")
        let messy = "fn  probe( ) {}\n"
        let disk = { (try? String(contentsOf: file, encoding: .utf8)) ?? "" }
        let editAndSave = {
            guard let view = e.view else {
                return
            }
            view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
            e.type("\n")
            state.saveActive()
        }
        return [
            SelfTestStep(name: "pref format on save on", until: { disk().hasPrefix("fn probe() {}") }, timeout: 15, run: {
                try? messy.write(to: file, atomically: true, encoding: .utf8)
                state.openFile(file)
                bind.bool(\.formatOnSave).wrappedValue = true
                DemoLaunch.after(0.8, editAndSave)
            }, check: {
                e.expect(disk().hasPrefix("fn probe() {}"), "disk '\(disk())'")
            }),
            SelfTestStep(name: "pref format on save off", wait: 2.5, run: {
                bind.bool(\.formatOnSave).wrappedValue = false
                e.view?.replaceText(in: NSRange(location: 0, length: (e.text as NSString).length), with: messy)
                editAndSave()
            }, check: {
                let saved = disk()
                if let buffer = state.buffers.first(where: { $0.fileURL == file }) {
                    state.dropBuffer(buffer)
                }
                try? FileManager.default.removeItem(at: file)
                state.openFile(root.appendingPathComponent("src/main.rs"))
                return e.expect(saved.hasPrefix(messy), "disk '\(saved)'")
            }),
        ]
    }
}
