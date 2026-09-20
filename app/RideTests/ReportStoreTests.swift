import XCTest

final class ReportStoreTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ride-reports-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func write(_ name: String, body: String, at seconds: Double) throws {
        let url = directory.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: seconds)],
            ofItemAtPath: url.path
        )
    }

    func testListsNewestFirst() throws {
        try write("crash-100.txt", body: "old", at: 100)
        try write("crash-300.txt", body: "new", at: 300)
        try write("panics.jsonl", body: "{}", at: 200)
        let names = ReportStore(directory: directory).all().map(\.name)
        XCTAssertEqual(names, ["crash-300.txt", "panics.jsonl", "crash-100.txt"])
    }

    func testAcknowledgedFilterDropsOlderReports() throws {
        try write("crash-100.txt", body: "old", at: 100)
        try write("crash-300.txt", body: "new", at: 300)
        let fresh = ReportStore(directory: directory).new(since: 200)
        XCTAssertEqual(fresh.map(\.name), ["crash-300.txt"])
    }

    func testPruneKeepsTwentyNewestCrashesAndSparesThePanicLog() throws {
        for index in 1...25 {
            try write("crash-\(index).txt", body: "boom", at: Double(index))
        }
        try write("panics.jsonl", body: "{}", at: 0)
        let store = ReportStore(directory: directory)
        store.prune()
        let remaining = store.all()
        XCTAssertEqual(remaining.filter(\.isCrash).count, 20)
        XCTAssertTrue(remaining.contains { $0.name == "panics.jsonl" })
        XCTAssertFalse(remaining.contains { $0.name == "crash-5.txt" })
        XCTAssertTrue(remaining.contains { $0.name == "crash-25.txt" })
    }

    func testConcatenatedTextCarriesEveryReport() throws {
        try write("crash-100.txt", body: "first", at: 100)
        try write("crash-300.txt", body: "second", at: 300)
        let store = ReportStore(directory: directory)
        let text = store.text(of: store.all())
        XCTAssertTrue(text.contains("=== crash-300.txt ==="))
        XCTAssertTrue(text.contains("first"))
        XCTAssertTrue(text.contains("second"))
    }

    func testNoticeTextDependsOnTheKindOfReport() {
        let crash = ReportFile(url: directory.appendingPathComponent("crash-1.txt"), modified: 1)
        let panic = ReportFile(url: directory.appendingPathComponent("panics.jsonl"), modified: 1)
        XCTAssertEqual(ReportStore.noticeText(for: [panic, crash]), "Ride crashed last time")
        XCTAssertEqual(ReportStore.noticeText(for: [panic]), "Ride hit an internal error last time")
    }

    func testMissingDirectoryYieldsNoReports() {
        let store = ReportStore(directory: directory.appendingPathComponent("absent", isDirectory: true))
        XCTAssertTrue(store.all().isEmpty)
        store.prune()
    }
}
