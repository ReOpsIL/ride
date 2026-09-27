import XCTest

final class RunConfigDraftTests: XCTestCase {
    func testArgsSplitOnSpacesAndQuotes() {
        XCTAssertEqual(RunArgs.split("a  \"b c\" 'd' \"\""), ["a", "b c", "d", ""])
        XCTAssertEqual(RunArgs.split(""), [])
    }

    func testJoinQuotesArgsWithSpaces() {
        let args = ["--name", "two words"]
        XCTAssertEqual(RunArgs.join(args), "--name \"two words\"")
        XCTAssertEqual(RunArgs.split(RunArgs.join(args)), args)
    }

    func testDraftRoundTripsTheConfig() {
        let config = RunConfig(
            target: "demo",
            buildArgs: ["--release"],
            args: ["--fast"],
            env: ["A": "1", "B": "2"],
            workingDir: "/w",
            rustBacktrace: true,
            sanitizers: [.address]
        )
        XCTAssertEqual(RunConfigDraft(config).config(target: "demo"), config)
    }

    func testRowsWithoutKeysAreDropped() {
        var draft = RunConfigDraft()
        draft.env = [RunConfigEnvRow(key: "", value: "x"), RunConfigEnvRow(key: "K", value: "v")]
        XCTAssertEqual(draft.config(target: "t").env, ["K": "v"])
        XCTAssertNil(draft.config(target: "t").workingDir)
    }

    func testConflictingSanitizersReplaceEachOther() {
        var draft = RunConfigDraft()
        draft.set(.address, on: true)
        draft.set(.undefined, on: true)
        draft.set(.thread, on: true)
        XCTAssertEqual(draft.sanitizers, [.thread, .undefined])
        draft.set(.thread, on: false)
        XCTAssertEqual(draft.sanitizers, [.undefined])
    }
}
