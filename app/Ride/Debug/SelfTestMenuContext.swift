import AppKit

final class SelfTestMenuContext {
    static let probeSource = """
    pub trait Probe {
        fn bump(&mut self);
    }

    pub struct MenuProbe {
        pub hits: u32,
    }

    impl Probe for MenuProbe {
        fn bump(&mut self) {
            self.hits += 1;
        }
    }

    pub fn menu_probe_used() -> u32 {
        let mut probe = MenuProbe { hits: 0 };
        probe.bump();
        probe.bump();
        probe.hits
    }

    fn menu_probe_unused() {}

    fn menu_lines() {
        let b = 2;
        let a = 1;
        let c = 3;
    }

    """

    let state: AppState
    let e: SelfTestEditor
    let root: URL?
    var pressed: [String: Bool] = [:]
    var number = 0
    var flag = false
    var location = 0
    var windows: [NSWindow] = []
    var shownWindows: [NSWindow] = []
    var opened: [NSWindow] = []
    var pasteboard: String?
    var target: String?

    init(state: AppState, e: SelfTestEditor) {
        self.state = state
        self.e = e
        root = state.workspaceRoot
    }

    func url(_ relative: String) -> URL? {
        root?.appendingPathComponent(relative).standardizedFileURL
    }

    var probeURL: URL? {
        url("src/menu_probe.rs")
    }

    func script(_ answer: Any?) {
        DialogScript.clear()
        if let answer {
            DialogScript.push(answer)
        }
    }

    func press(_ path: String, activating: Bool = true) {
        if activating {
            e.activate()
        }
        if NSApp.keyWindow == nil, let item = SelfTestMenu.item(path), item.target == nil, let action = item.action,
           let view = e.view, view.responds(to: action) {
            pressed[path] = view.validateUserInterfaceItem(item) && NSApp.sendAction(action, to: view, from: item)
            return
        }
        pressed[path] = SelfTestMenu.perform(path)
    }

    func step(
        _ name: String,
        _ path: String,
        wait: Double = 0.3,
        until: (() -> Bool)? = nil,
        timeout: Double = 0,
        activating: Bool = true,
        prepare: @escaping () -> Void = {},
        check: @escaping () -> (ok: Bool, detail: String)
    ) -> SelfTestStep {
        SelfTestStep(name: name, wait: wait, until: until, timeout: timeout, run: {
            prepare()
            self.press(path, activating: activating)
        }, check: {
            let result = check()
            return self.expect(path, result.ok, result.detail)
        })
    }

    func expect(_ path: String, _ condition: Bool, _ message: @autoclosure () -> String) -> String? {
        guard pressed[path] == true else {
            return "\(path) was disabled or missing (app active \(NSApp.isActive))"
        }
        return condition ? nil : message()
    }

    var activeName: String {
        state.activeBuffer?.fileURL?.lastPathComponent ?? state.activeBuffer?.displayName ?? "nil"
    }

    func openProbe() {
        guard let url = probeURL else {
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Self.probeSource.write(to: url, atomically: true, encoding: .utf8)
        }
        state.openFile(url)
        e.activate()
    }

    func shows(_ url: URL?) -> Bool {
        guard let url else {
            return false
        }
        return e.view?.hooks.binding?()?.document.fileURL == url
    }

    func openStep(_ name: String, _ url: URL?) -> SelfTestStep {
        SelfTestStep(name: name, wait: 0.4, until: { self.shows(url) }, timeout: 10, run: {
            if url == self.probeURL {
                self.openProbe()
            } else if let url {
                self.state.openFile(url)
            }
            self.e.activate()
        }, check: {
            self.e.expect(self.shows(url), "view shows \(self.e.view?.hooks.binding?()?.document.displayName ?? "nil")")
        })
    }

    func resetProbe() {
        guard let view = e.view, shows(probeURL) else {
            return
        }
        if view.string != Self.probeSource {
            view.insertText(Self.probeSource, replacementRange: NSRange(location: 0, length: (view.string as NSString).length))
        }
        if let binding = view.hooks.binding?() {
            SessionService.shared.resync(document: binding.document, view: view)
        }
    }

    func lineOf(_ needle: String) -> Int {
        (e.lines.firstIndex { $0.contains(needle) } ?? -1) + 1
    }

    func caret(on needle: String, offset: Int = 0) {
        let range = (e.text as NSString).range(of: needle)
        guard range.location != NSNotFound else {
            return
        }
        e.view?.setSelectedRange(NSRange(location: range.location + offset, length: 0))
    }

    func select(_ needle: String) {
        let range = (e.text as NSString).range(of: needle)
        if range.location != NSNotFound {
            e.view?.setSelectedRange(range)
        }
    }

    func disk(_ url: URL?) -> String {
        url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    var newWindows: [NSWindow] {
        NSApp.windows.filter { window in
            guard window.styleMask.contains(.titled) else {
                return false
            }
            let known = windows.contains { $0 === window }
            let shownBefore = shownWindows.contains { $0 === window }
            return window.isVisible ? !shownBefore : !known && !NSApp.isActive
        }
    }

    func snapshotWindows() {
        windows = NSApp.windows
        shownWindows = NSApp.windows.filter(\.isVisible)
    }
}
