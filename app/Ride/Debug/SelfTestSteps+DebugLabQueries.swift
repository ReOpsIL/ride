import AppKit

extension SelfTestSteps {
    static func labFrames(_ state: AppState) -> [String] {
        state.debugPanel.frames.map(\.name)
    }

    static func labTop(_ state: AppState, is function: String) -> Bool {
        debugStopped(state) && state.debugPanel.frames.first?.name.contains(function) == true
    }

    static func labLocal(_ state: AppState, _ name: String) -> String? {
        state.debugPanel.tree.rows.first { $0.node.name == name }?.node.value
    }

    static func labWatch(_ state: AppState, _ expression: String) -> String? {
        state.debugPanel.watches.first { $0.id == expression }.flatMap { $0.value.isEmpty ? nil : $0.value }
    }

    static func labShows(_ state: AppState, e: SelfTestEditor, file: String, line: UInt32) -> Bool {
        let path = debugPath(state) ?? ""
        return path.hasSuffix(file) && SelfTestMarkedLine.isTinted(e.view, line: Int(line))
    }

    static func labFollows(_ state: AppState, e: SelfTestEditor) -> Bool {
        guard let stopped = state.debug.stoppedPath else {
            return false
        }
        return labShows(state, e: e, file: (stopped as NSString).lastPathComponent, line: state.debug.stoppedLine)
    }

    static func labWhere(_ state: AppState) -> String {
        "state \(state.debug.state) at \(stoppedFile(state)):\(state.debug.stoppedLine) editor \(debugPath(state).map { ($0 as NSString).lastPathComponent } ?? "nil") frames \(labFrames(state).prefix(8)) "
            + SelfTestRunScratch.status(state)
    }
}
