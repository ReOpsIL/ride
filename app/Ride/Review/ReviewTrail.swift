import Foundation

enum ReviewTrail {
    static func tests(_ rows: [TestRow]) {
        for row in rows where row.outcome == .passed || row.outcome == .failed {
            append(
                kind: "test",
                name: row.name,
                path: "",
                passed: row.outcome == .passed,
                note: String(row.output.prefix(200))
            )
        }
    }

    static func stop(frames: [StackFrame], watches: [WatchRow]) {
        guard let top = frames.first else {
            return
        }
        let names = frames.map(\.name).joined(separator: "\n")
        let watch = watches.prefix(6).map { "\($0.expression)=\($0.value)" }.joined(separator: ", ")
        append(kind: "debug", name: top.name, path: top.path ?? "", passed: false, note: names + "\n" + watch)
    }

    static func cite(frames: [StackFrame], watches: [WatchRow]) -> String {
        let top = frames.first
        let whereAt = "\(top?.path ?? ""):\(top?.line ?? 0)"
        let watch = watches.prefix(4).map { "\($0.expression) = \($0.value)" }.joined(separator: ", ")
        if watch.isEmpty {
            return "stop at \(whereAt)"
        }
        return "stop at \(whereAt), \(watch)"
    }

    private static func append(kind: String, name: String, path: String, passed: Bool, note: String) {
        guard let root = RideEngineClient.shared.openRoot?.path else {
            return
        }
        RideEngineClient.shared.withEngine { engine in
            try? engine.reviewTrail(root: root, kind: kind, name: name, path: path, passed: passed, note: note)
        } then: { _ in }
    }
}
