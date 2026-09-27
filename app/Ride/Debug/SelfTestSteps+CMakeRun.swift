import AppKit

extension SelfTestSteps {
    static func cmakeRunSteps(state: AppState, e: SelfTestEditor, binary: String, output: String) -> [SelfTestStep] {
        let scratch = SelfTestRunScratch()
        return [
            menuRecompileFile(state: state, e: e, scratch: scratch),
            cmakeSanitizerBuild(state: state, e: e, scratch: scratch),
            cmakeSanitizerRun(state: state, e: e, binary: binary, output: output),
            cmakeReleaseBuild(state: state, e: e, binary: binary),
            cmakeRestore(state: state, e: e, scratch: scratch),
        ]
    }

    private static func menuRecompileFile(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "menu recompile file", wait: 0.5, until: { SelfTestRunScratch.finished(state) }, timeout: 120, run: {
            e.focus()
            scratch.performed = SelfTestMenu.perform("Run › Recompile File")
        }, check: {
            let session = state.runOutput.lastRequest?.session
            let single: Bool
            if case .singleFile = session {
                single = true
            } else {
                single = false
            }
            return e.expect(
                scratch.performed && single && state.runOutput.status == "exit 0" && state.runOutput.command?.contains("-c") == true,
                "performed \(scratch.performed) session \(String(describing: session)) " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func cmakeSanitizerBuild(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "cmake sanitizer build", wait: 0.5, until: { cmakeBuilt(state, dir: "build/Debug-address") }, timeout: 300, run: {
            scratch.configs = state.runConfigs
            scratch.profile = state.projectModel.profile
            SelfTestMenu.perform("Run › Edit Configurations…")
            scratch.performed = state.runConfigEditor.sanitizers == Sanitizer.allCases
            state.runConfigEditor.set(.address, on: true)
            state.saveRunConfig()
            SelfTestMenu.perform("Run › Build")
        }, check: {
            let cache = cmakeCache(state, dir: "build/Debug-address")
            return e.expect(
                scratch.performed && cmakeBuilt(state, dir: "build/Debug-address") && state.runOutput.status == "exit 0"
                    && cache.contains("-fsanitize=address"),
                "all sanitizers \(scratch.performed) sanitized cache \(cache.contains("-fsanitize=address")) " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func cmakeSanitizerRun(state: AppState, e: SelfTestEditor, binary: String, output: String) -> SelfTestStep {
        SelfTestStep(name: "cmake sanitizer run", wait: 0.5, until: { SelfTestRunScratch.finished(state) }, timeout: 60, run: {
            SelfTestMenu.perform("Run › Run")
        }, check: {
            e.expect(
                state.runOutput.status == "exit 0" && state.runOutput.command == "build/Debug-address/\(binary)"
                    && state.runOutput.text.contains(output),
                "command \(state.runOutput.command ?? "nil") " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func cmakeReleaseBuild(state: AppState, e: SelfTestEditor, binary: String) -> SelfTestStep {
        SelfTestStep(name: "cmake release profile build", wait: 0.5, until: { cmakeBuilt(state, dir: "build/Release") }, timeout: 300, run: {
            SelfTestMenu.perform("Run › Edit Configurations…")
            state.runConfigEditor.set(.address, on: false)
            state.saveRunConfig()
            state.projectModel.choose(profile: "Release")
            SelfTestMenu.perform("Run › Build")
        }, check: {
            let root = state.activeProjectRoot?.path ?? ""
            let built = FileManager.default.isExecutableFile(atPath: root + "/build/Release/" + binary)
            return e.expect(
                built && state.runOutput.status == "exit 0" && cmakeCache(state, dir: "build/Release").contains("CMAKE_BUILD_TYPE:STRING=Release"),
                "built \(built) " + SelfTestRunScratch.status(state)
            )
        })
    }

    private static func cmakeRestore(state: AppState, e: SelfTestEditor, scratch: SelfTestRunScratch) -> SelfTestStep {
        SelfTestStep(name: "cmake run restore", wait: 0.3, run: {
            state.runConfigs = scratch.configs
            state.projectModel.choose(profile: scratch.profile)
        }, check: {
            e.expect(
                state.projectModel.profile == scratch.profile && state.runPlan(.build)?.prelude == nil,
                "profile \(state.projectModel.profile) prelude \(state.runPlan(.build)?.prelude ?? [])"
            )
        })
    }

    private static func cmakeBuilt(_ state: AppState, dir: String) -> Bool {
        SelfTestRunScratch.finished(state) && state.runOutput.command?.hasPrefix("cmake --build \(dir)") == true
            || (SelfTestRunScratch.finished(state) && state.runOutput.status != "exit 0")
    }

    private static func cmakeCache(_ state: AppState, dir: String) -> String {
        let root = state.activeProjectRoot?.path ?? ""
        return (try? String(contentsOfFile: root + "/" + dir + "/CMakeCache.txt", encoding: .utf8)) ?? ""
    }
}
