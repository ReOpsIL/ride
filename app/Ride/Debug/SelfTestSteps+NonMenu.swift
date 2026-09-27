extension SelfTestSteps {
    static func nonMenuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let show = { (name: String) in showFile(name, state: state, e: e) }
        let sources = ProbeSources()
        return [pristineSources(state: state, e: e, sources: sources)]
            + shortcutSteps(state: state, e: e)
            + editorKeySteps(state: state, e: e)
            + [show("show main before find bar")] + findBarSteps(state: state, e: e)
            + [show("show main before status bar")] + statusBarSteps(state: state, e: e)
            + [show("show main before tree")] + sidebarSteps(state: state, e: e)
            + [show("show main before tabs")] + tabSteps(state: state, e: e)
            + [show("show main before project find")] + projectFindSteps(state: state, e: e)
            + [show("show main before preferences")] + prefSteps(state: state, e: e)
            + [restoreSources(state: state, e: e, sources: sources)]
    }
}
