import AppKit

extension SelfTestSteps {
    static func statusBarSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let root = state.workspaceRoot ?? URL(fileURLWithPath: "/")
        let file = root.appendingPathComponent("ride_crlf_probe.txt")
        let disk = { (try? Data(contentsOf: file)).map { String(decoding: $0, as: UTF8.self) } ?? "" }
        let buffer = { state.buffers.first { $0.fileURL?.lastPathComponent == file.lastPathComponent } }
        let choose = { (title: String) in
            guard let buffer = buffer() else {
                return
            }
            let menu = LineEndingMenu.menu(buffer: buffer, policy: state.prefs.lineEndings)
            if let index = menu.items.firstIndex(where: { $0.title == title }) {
                menu.performActionForItem(at: index)
            }
        }
        return [
            SelfTestStep(name: "status line ending to LF", wait: 0.6, run: {
                try? Data("a\r\nb\r\n".utf8).write(to: file)
                state.openFile(file)
                DemoLaunch.after(0.3) {
                    choose("LF")
                    state.saveActive()
                }
            }, check: {
                e.expect(buffer()?.lineEnding == "LF" && disk() == "a\nb\n" && state.prefs.lineEndings == LineEndings.keep,
                         "ending \(buffer()?.lineEnding ?? "-") disk \(disk().debugDescription) policy \(state.prefs.lineEndings)")
            }),
            SelfTestStep(name: "status line ending to CRLF", wait: 0.4, run: {
                choose("CRLF")
                state.saveActive()
            }, check: {
                e.expect(buffer()?.lineEnding == "CRLF" && disk() == "a\r\nb\r\n", "ending \(buffer()?.lineEnding ?? "-") disk \(disk().debugDescription)")
            }),
            SelfTestStep(name: "pref line endings convert to LF", wait: 0.4, run: {
                PreferenceBindings(state: state).string(\.lineEndings).wrappedValue = LineEndings.lf
                e.view.map { $0.setSelectedRange(NSRange(location: ($0.string as NSString).length, length: 0)) }
                e.type("c")
                state.saveActive()
            }, check: {
                let crlfEnabled = buffer().map { LineEndingMenu.menu(buffer: $0, policy: state.prefs.lineEndings).items.last?.isEnabled ?? true } ?? true
                PreferenceBindings(state: state).string(\.lineEndings).wrappedValue = LineEndings.keep
                let saved = disk()
                if let buffer = buffer() {
                    state.dropBuffer(buffer)
                }
                try? FileManager.default.removeItem(at: file)
                state.openFile(root.appendingPathComponent("src/main.rs"))
                return e.expect(saved == "a\nb\nc" && !crlfEnabled, "disk \(saved.debugDescription) CRLF enabled \(crlfEnabled)")
            }),
            SelfTestStep(name: "status check segment toggles problems", run: {
                state.showProblems = false
                state.toggleProblems()
            }, check: {
                let opened = state.showProblems
                state.toggleProblems()
                return e.expect(opened && !state.showProblems, "opened \(opened) closed \(!state.showProblems)")
            }),
            SelfTestStep(name: "status indentation label", run: {}, check: {
                let label = IndentLabel.text(language: state.activeBuffer?.language, tabWidth: state.prefs.tabWidth)
                return e.expect(label == "Spaces: \(state.prefs.tabWidth)" && IndentLabel.text(language: .make, tabWidth: 4) == "Tabs", label)
            }),
        ] + problemsSteps(state: state, e: e)
    }
}
