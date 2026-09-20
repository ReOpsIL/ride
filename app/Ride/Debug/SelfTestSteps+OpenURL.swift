import AppKit

extension SelfTestSteps {
    static func openURLSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [
            SelfTestStep(name: "ride url opens file at line", wait: 0.6, until: {
                opened(state: state, e: e)
            }, timeout: 20, run: {
                guard let url = openURL(state: state) else {
                    return
                }
                RideAppDelegate.open([url])
            }, check: {
                e.expect(
                    opened(state: state, e: e),
                    "active \(state.activeBuffer?.fileURL?.lastPathComponent ?? "nil") caret \(e.caretLine)"
                )
            }),
        ]
    }

    private static func opened(state: AppState, e: SelfTestEditor) -> Bool {
        state.activeBuffer?.fileURL?.lastPathComponent == "util.rs" && e.caretLine == 3
    }

    private static func openURL(state: AppState) -> URL? {
        guard let root = state.workspaceRoot else {
            return nil
        }
        let path = root.appendingPathComponent("src/util.rs").path
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "ride://open?path=\(encoded)&line=3")
    }
}
