import AppKit

extension SelfTestSteps {
    static func menuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let c = SelfTestMenuContext(state: state, e: e)
        let groups: [[SelfTestStep]] = [
            menusApp(c),
            menusFile(c),
            menusEditLines(c),
            menusEditClipboard(c),
            menusFind(c),
            menusView(c),
            menusSplit(c),
            menusOverlays(c),
            menusNavigate(c),
            menusRename(c),
            menusQuit(c),
            menusWorkspace(c),
        ]
        return groups.flatMap { $0 }
    }
}
