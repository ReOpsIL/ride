import AppKit

extension SelfTestSteps {
    static func cppMenuSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        let stash = SelfTestStash()
        let block = "\n\nstruct GenMenuBase {\n    int tag_;\n};\nstruct GenMenu : GenMenuBase {\n    std::string gname_;\n    int gy_;\n};\n"
        let titles = ["Constructor", "Getters", "Setters", "Equality operators", "Stream operator"]
        let cases = [
            PopupCase(title: "Constructor", expect: ["GenMenu(std::string gname, int gy) : gname_(gname), gy_(gy) {}"]),
            PopupCase(title: "Getters", expect: ["std::string gname() const { return gname_; }"]),
            PopupCase(title: "Setters", expect: ["void set_gy(int value) { gy_ = value; }"]),
            PopupCase(title: "Equality operators", expect: ["bool operator==(const GenMenu& other) const"]),
            PopupCase(title: "Stream operator", expect: ["operator<<"]),
        ]
        let popups = cases.map { item -> SelfTestStep in
            var pick = item
            pick.prepare = { e.place(on: "int gy_;") }
            return popupStep("generate popup \(item.title)", menu: "Code › Generate…", e: e, reset: { MenuBlock.reset(e, stash, block: block) }, titles: titles, pick: pick)
        }
        return [
            SelfTestStep(name: "cpp menu prep", wait: 1.0, run: {
                MenuBlock.open(state: state, e: e, stash: stash, file: "src/shapes.cpp")
                MenuBlock.reset(e, stash, block: block)
            }, check: { e.expect(e.text.contains("struct GenMenu :"), "no GenMenu") }),
            gateStep("cpp code menu gates", e: e, enabled: CodeMenuPaths.editor + CodeMenuPaths.language + CodeMenuPaths.rustAndCpp, disabled: []),
        ] + popups + [
            checkMenuStep("menu check cpp", "Build › Check", state: state, e: e, stash: stash) {
                state.activeBuffer?.fileURL.map(CheckPlan.clangFile)
            },
            SelfTestStep(name: "cpp menu restore", run: { MenuBlock.restore(e, stash) }, check: {
                e.expect(e.text == stash.original, "shapes.cpp not restored")
            }),
        ]
    }
}
