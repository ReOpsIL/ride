import Foundation

final class SelfTestRunScratch {
    var performed = false
    var paused = false
    var step: RunRequest?
    var configs: [RunConfig] = []
    var profile = ""
    var line = ""
    var tabs = 0
    var terminal: UUID?

    static func finished(_ state: AppState) -> Bool {
        !state.runOutput.isRunning && state.runOutput.status != nil
    }

    static func status(_ state: AppState) -> String {
        "status \(state.runOutput.status ?? "nil") text \(state.runOutput.text.suffix(240))"
    }
}
