import AppKit

final class DiskChangeScratch {
    var original = ""
}

extension SelfTestSteps {
    static func changedOnDiskSteps(t: TabProbe, e: SelfTestEditor) -> [SelfTestStep] {
        let d = DiskChangeScratch()
        let main = t.url("src/main.rs")
        let disk = { (try? String(contentsOf: main, encoding: .utf8)) ?? "" }
        let external = "// ride external edit\n"
        let conflict = {
            t.state.updatePrefs { $0.autoSave = false }
            d.original = disk()
            e.place(on: "mod util;", atEnd: true)
            e.type(" ")
            try? (external + d.original).write(to: main, atomically: true, encoding: .utf8)
            t.state.diskChanged(paths: [main.path])
        }
        return [
            SelfTestStep(name: "changed on disk cancel", run: {
                conflict()
                DialogScript.answers = [OverwriteChoice.cancel]
                t.state.saveActive()
            }, check: {
                e.expect(disk().hasPrefix(external) && t.state.activeBuffer?.isDirty == true && DialogScript.answers.isEmpty, "saved over the external edit")
            }),
            SelfTestStep(name: "changed on disk reload", run: {
                DialogScript.answers = [OverwriteChoice.reload]
                t.state.saveActive()
            }, check: {
                let reloaded = e.text.hasPrefix(external) && t.state.activeBuffer?.isDirty == false
                try? d.original.write(to: main, atomically: true, encoding: .utf8)
                t.state.activeBuffer.map(t.state.reloadFromDisk)
                return e.expect(reloaded && DialogScript.answers.isEmpty, "buffer did not reload")
            }),
            SelfTestStep(name: "changed on disk overwrite", run: {
                conflict()
                DialogScript.answers = [OverwriteChoice.overwrite]
                t.state.saveActive()
            }, check: {
                let written = !disk().hasPrefix(external) && disk().contains("mod util; ")
                try? d.original.write(to: main, atomically: true, encoding: .utf8)
                t.state.activeBuffer.map(t.state.reloadFromDisk)
                t.state.updatePrefs { $0.autoSave = true }
                return e.expect(written && e.text == d.original, "overwrite \(written)")
            }),
        ]
    }
}
