import AppKit

extension SelfTestSteps {
    static func menusApp(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        windowSteps(c, name: "about", path: "Ride › About Ride", close: nil)
            + windowSteps(c, name: "settings", path: "Ride › Settings…", close: "File › Close Editor")
            + windowSteps(c, name: "shortcuts", path: "Help › Keyboard Shortcuts", close: "File › Close Editor")
            + [
                c.step("menu hide", "Ride › Hide Ride", wait: 0.5) {
                    (NSApp.isHidden, "hidden \(NSApp.isHidden)")
                },
                SelfTestStep(name: "menu unhide", wait: 0.5, run: {
                    NSApp.unhide(nil)
                    c.e.activate()
                }, check: { c.e.expect(!NSApp.isHidden, "still hidden") }),
            ]
    }

    private static func windowSteps(_ c: SelfTestMenuContext, name: String, path: String, close: String?) -> [SelfTestStep] {
        let titles = { c.opened.map(\.title) }
        return [
            c.step("menu \(name)", path, until: { !c.newWindows.isEmpty }, timeout: 3, prepare: { c.snapshotWindows() }) {
                c.opened = c.newWindows
                return (!c.opened.isEmpty, "no new window, app active \(NSApp.isActive)")
            },
            SelfTestStep(name: "menu \(name) close", wait: 0.4, run: {
                c.number = c.state.buffers.count
                guard let close, let window = c.opened.first, NSApp.isActive else {
                    c.opened.forEach { $0.close() }
                    return
                }
                window.makeKeyAndOrderFront(nil)
                c.press(close, activating: false)
            }, check: {
                let open = c.opened.filter(\.isVisible)
                c.opened.forEach { $0.close() }
                return c.e.expect(open.isEmpty && c.state.buffers.count == c.number, "open \(titles()) buffers \(c.state.buffers.count) of \(c.number)")
            }),
        ]
    }

    static func menusQuit(_ c: SelfTestMenuContext) -> [SelfTestStep] {
        let state = c.state
        let path = "Ride › Quit Ride"
        return [
            SelfTestStep(name: "menu quit cancel", run: {
                DialogScript.clear()
                c.resetProbe()
                c.e.type("x")
                c.pressed[path] = false
                guard state.activeBuffer?.isDirty == true else {
                    return
                }
                DialogScript.push(CloseChoice.cancel)
                c.press(path)
            }, check: {
                let dirty = state.activeBuffer?.isDirty == true
                let consumed = DialogScript.pending == 0
                DialogScript.clear()
                return c.expect(path, dirty && consumed, "active \(c.activeName) dirty \(dirty) consumed \(consumed)")
            }),
        ]
    }
}
