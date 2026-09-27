import Foundation

struct SelfTestStep {
    let name: String
    var wait: Double = 0.25
    var until: (() -> Bool)?
    var timeout: Double = 0
    let run: () -> Void
    let check: () -> String?
}
