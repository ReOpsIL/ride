import Foundation

enum BuildFinish: Equatable {
    case ignore
    case discard
    case publish
}

struct BuildSessionState: Equatable {
    private(set) var runId: Int?

    var isActive: Bool {
        runId != nil
    }

    mutating func begin(runId: Int) {
        self.runId = runId
    }

    mutating func cancel() {
        runId = nil
    }

    func accepts(runId: Int) -> Bool {
        self.runId == runId
    }

    mutating func finish(runId: Int, status: RunFinish) -> BuildFinish {
        guard self.runId == runId else {
            return .ignore
        }
        self.runId = nil
        return status.isClean ? .publish : .discard
    }
}

struct RunChainState: Equatable {
    private(set) var runId: Int?

    mutating func expect(runId: Int) {
        self.runId = runId
    }

    mutating func cancel() {
        runId = nil
    }

    mutating func take(runId: Int, status: RunFinish) -> Bool {
        guard self.runId == runId else {
            return false
        }
        self.runId = nil
        return status.succeeded
    }
}
