import Foundation

enum TestOutcome: String, Equatable {
    case running
    case passed
    case failed
    case ignored
}

enum TestMarkerFramework: String, Equatable {
    case cargo
    case googleTest
    case catch2
    case ctest
}

struct TestMarkerRow: Equatable {
    var name: String
    var framework: TestMarkerFramework?
}

struct TestRow: Equatable, Identifiable {
    var suite: String
    var name: String
    var outcome: TestOutcome
    var output: String = ""
    var durationMs: UInt64?

    var id: String {
        suite.isEmpty ? name : "\(suite)::\(name)"
    }
}

struct TestGroup: Equatable, Identifiable {
    var suite: String
    var rows: [TestRow]

    var id: String {
        suite
    }
}

struct TestTree: Equatable {
    private(set) var rows: [TestRow] = []

    var passed: Int {
        count(.passed)
    }

    var failed: Int {
        count(.failed)
    }

    var ignored: Int {
        count(.ignored)
    }

    var running: Int {
        count(.running)
    }

    var failedNames: [String] {
        rows.filter { $0.outcome == .failed }.map(\.name)
    }

    mutating func clear() {
        rows = []
    }

    mutating func apply(_ row: TestRow) {
        guard let at = rows.firstIndex(where: { $0.id == row.id }) else {
            rows.append(row)
            return
        }
        guard row.outcome != .running || rows[at].outcome == .running else {
            return
        }
        rows[at] = TestRow(
            suite: row.suite,
            name: row.name,
            outcome: row.outcome,
            output: row.output.isEmpty ? rows[at].output : row.output,
            durationMs: row.durationMs ?? rows[at].durationMs
        )
    }

    func row(id: String) -> TestRow? {
        rows.first { $0.id == id }
    }

    func groups(filter: String = "") -> [TestGroup] {
        let needle = filter.trimmingCharacters(in: .whitespaces).lowercased()
        var order: [String] = []
        var bySuite: [String: [TestRow]] = [:]
        for row in rows where needle.isEmpty || row.id.lowercased().contains(needle) {
            if bySuite[row.suite] == nil {
                order.append(row.suite)
            }
            bySuite[row.suite, default: []].append(row)
        }
        return order.map { TestGroup(suite: $0, rows: bySuite[$0] ?? []) }
    }

    private func count(_ outcome: TestOutcome) -> Int {
        rows.filter { $0.outcome == outcome }.count
    }
}

enum TestFilterCommand {
    static func argv(names: [String], framework: TestMarkerFramework, base: [String]) -> [String]? {
        guard !names.isEmpty, !base.isEmpty else {
            return nil
        }
        switch framework {
        case .cargo:
            return base + ["--", "--exact"] + names
        case .googleTest:
            return base + ["--gtest_filter=" + names.joined(separator: ":")]
        case .catch2:
            return base + names
        case .ctest:
            return base + ["-R", names.joined(separator: "|")]
        }
    }
}
