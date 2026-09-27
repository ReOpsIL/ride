import Foundation

final class SelfTestMenuPress {
    let path: String
    private(set) var pressed = false

    init(_ path: String) {
        self.path = path
    }

    func reset() {
        pressed = false
    }

    func pressWhenEnabled() -> Bool {
        if !pressed, SelfTestMenu.isEnabled(path) {
            pressed = SelfTestMenu.perform(path)
        }
        return pressed
    }

    func until(_ done: @escaping () -> Bool) -> () -> Bool {
        { [self] in pressWhenEnabled() && done() }
    }
}

extension SelfTestSteps {
    static func menuStep(
        _ name: String,
        _ path: String,
        timeout: Double,
        prepare: @escaping () -> Void = {},
        done: @escaping () -> Bool = { true },
        check: @escaping (Bool) -> String?
    ) -> SelfTestStep {
        let press = SelfTestMenuPress(path)
        return SelfTestStep(name: name, wait: 0.5, until: press.until(done), timeout: timeout, run: {
            press.reset()
            prepare()
        }, check: { check(press.pressed) })
    }
}
