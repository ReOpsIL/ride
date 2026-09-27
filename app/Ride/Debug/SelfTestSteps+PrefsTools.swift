import AppKit

extension SelfTestSteps {
    static func prefToolSteps(state: AppState, e: SelfTestEditor, bind: PreferenceBindings, p: PrefScratch) -> [SelfTestStep] {
        let main = { state.activeBuffer?.fileURL }
        let disk = { main().flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "" }
        let spaceAfterMod = {
            e.place(on: "mod util;", atEnd: true)
            e.type(" ")
        }
        let removeSpace = { e.view?.deleteBackward(nil) }
        return [
            SelfTestStep(name: "pref auto-save off", wait: 2, run: {
                bind.bool(\.autoSave).wrappedValue = false
                p.disk = disk()
                spaceAfterMod()
            }, check: {
                e.expect(state.activeBuffer?.isDirty == true && disk() == p.disk, "dirty \(state.activeBuffer?.isDirty == true) disk changed \(disk() != p.disk)")
            }),
            SelfTestStep(name: "pref auto-save on", until: { state.activeBuffer?.isDirty == false }, timeout: 5, run: {
                bind.bool(\.autoSave).wrappedValue = true
                removeSpace()
            }, check: {
                e.expect(state.activeBuffer?.isDirty == false && disk() == p.disk, "dirty \(state.activeBuffer?.isDirty == true)")
            }),
            SelfTestStep(name: "checks idle", until: {
                if CheckService.shared.running || CheckService.shared.version != p.version {
                    p.version = CheckService.shared.version
                    p.stableSince = Date()
                    return false
                }
                return Date().timeIntervalSince(p.stableSince) > 3
            }, timeout: 60, run: {
                p.version = CheckService.shared.version
                p.stableSince = Date()
            }, check: { e.expect(!CheckService.shared.running, "checks still running") }),
            SelfTestStep(name: "pref check on save off", wait: 3, run: {
                bind.bool(\.checkOnSave).wrappedValue = false
                p.version = CheckService.shared.version
                spaceAfterMod()
                state.saveActive()
            }, check: {
                e.expect(CheckService.shared.version == p.version && !CheckService.shared.running, "a check ran")
            }),
            SelfTestStep(name: "pref check on save on", until: { CheckService.shared.version != p.version }, timeout: 60, run: {
                bind.bool(\.checkOnSave).wrappedValue = true
                removeSpace()
                state.saveActive()
            }, check: {
                e.expect(CheckService.shared.version != p.version && disk() == p.disk, "no check after save")
            }),
        ] + formatOnSaveSteps(state: state, e: e, bind: bind) + [missingToolsOff(state: state, e: e, bind: bind), missingToolsOn(state: state, e: e, bind: bind), noticeBar(state: state, e: e, p: p)]
    }

    private static func missingToolsOff(state: AppState, e: SelfTestEditor, bind: PreferenceBindings) -> SelfTestStep {
        SelfTestStep(name: "pref missing tools off", wait: 3, run: {
            state.dismissNotice()
            bind.bool(\.askMissingTools).wrappedValue = false
            state.checkTools()
        }, check: {
            e.expect(!(state.notice ?? "").hasPrefix("Missing tools"), "notice '\(state.notice ?? "")'")
        })
    }

    private static func missingToolsOn(state: AppState, e: SelfTestEditor, bind: PreferenceBindings) -> SelfTestStep {
        SelfTestStep(name: "pref missing tools on", wait: 4, run: {
            bind.bool(\.askMissingTools).wrappedValue = true
            state.checkTools()
        }, check: {
            let missing = !ToolsModel.shared.missing.isEmpty
            let notice = (state.notice ?? "").hasPrefix("Missing tools")
            var sheet = false
            if notice, let action = state.noticeAction {
                action.run()
                sheet = state.showToolsSheet
                state.showToolsSheet = false
            }
            return e.expect(notice == missing && sheet == missing, "missing \(missing) notice \(notice) sheet \(sheet)")
        })
    }

    private static func noticeBar(state: AppState, e: SelfTestEditor, p: PrefScratch) -> SelfTestStep {
        SelfTestStep(name: "notice bar action and dismiss", run: {
            p.flag = false
            var dismissed = false
            state.showNotice("Ride probe notice", action: ("Run", { p.flag = true }), onDismiss: { dismissed = true })
            state.noticeAction?.run()
            state.dismissNotice()
            p.flag = p.flag && dismissed
        }, check: {
            e.expect(p.flag && state.notice != "Ride probe notice", "action/dismiss \(p.flag) notice \(state.notice ?? "-")")
        })
    }
}
