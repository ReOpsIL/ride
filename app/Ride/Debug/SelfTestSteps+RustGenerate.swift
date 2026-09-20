import AppKit

extension SelfTestSteps {
    static func rustGenerate(e: SelfTestEditor, scratch: SelfTestScratch) -> [SelfTestStep] {
        [
            SelfTestStep(name: "generate prep", wait: 1.0, run: {
                e.activate()
                guard let view = e.view, let binding = view.hooks.binding?() else {
                    return
                }
                scratch.saved = view.string
                let addition = "\n\nstruct GenPoint {\n    gx: i32,\n    gy: i32,\n}\n"
                let end = (view.string as NSString).length
                view.setSelectedRange(NSRange(location: end, length: 0))
                view.insertText(addition, replacementRange: NSRange(location: end, length: 0))
                SessionService.shared.resync(document: binding.document, view: view)
            }, check: { e.expect(e.text.contains("struct GenPoint"), "no GenPoint") }),
            SelfTestStep(name: "generate new", wait: 1.0, run: {
                e.activate()
                e.place(on: "gx: i32,")
                EditorCommands.applyGenerator(.new)
            }, check: {
                e.expect(
                    e.text.contains("impl GenPoint {") && e.text.contains("pub fn new(gx: i32, gy: i32) -> Self"),
                    "text \(e.text.suffix(300))"
                )
            }),
            SelfTestStep(name: "generate cleanup", run: {
                guard let view = e.view else {
                    return
                }
                let full = NSRange(location: 0, length: (view.string as NSString).length)
                view.insertText(scratch.saved, replacementRange: full)
                if let binding = view.hooks.binding?() {
                    SessionService.shared.resync(document: binding.document, view: view)
                }
            }, check: { e.expect(!e.text.contains("GenPoint"), "leftover") }),
        ]
    }
}
