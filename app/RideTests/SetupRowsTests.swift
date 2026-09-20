import XCTest

final class SetupRowsTests: XCTestCase {
    private func tools(missing: Set<String> = []) -> [SetupTool] {
        SetupRows.names.map { name in
            SetupTool(
                name: name,
                installed: !missing.contains(name),
                command: name == "cmake" ? "brew install cmake" : "install \(name)",
                manual: name == "rustup"
            )
        }
    }

    func testRowsFollowTheFixedOrderAndEndWithDebugging() {
        let rows = SetupRows.rows(tools: tools().shuffled(), developerMode: true)
        XCTAssertEqual(rows.map(\.name), SetupRows.names + [SetupRows.debuggingName])
        XCTAssertEqual(rows.first?.title, "Command Line Tools")
    }

    func testAllGreenWhenEverythingIsInstalledAndDeveloperModeIsOn() {
        XCTAssertTrue(SetupRows.allGreen(SetupRows.rows(tools: tools(), developerMode: true)))
    }

    func testDeveloperModeOffKeepsTheSectionOpen() {
        let rows = SetupRows.rows(tools: tools(), developerMode: false)
        XCTAssertFalse(SetupRows.allGreen(rows))
        let debugging = rows.last
        XCTAssertEqual(debugging?.command, SetupRows.debuggingCommand)
        XCTAssertEqual(debugging?.manual, true)
        XCTAssertEqual(debugging?.installed, false)
    }

    func testMissingToolCarriesItsCommand() {
        let rows = SetupRows.rows(tools: tools(missing: ["cmake"]), developerMode: true)
        XCTAssertFalse(SetupRows.allGreen(rows))
        let cmake = rows.first { $0.name == "cmake" }
        XCTAssertEqual(cmake?.installed, false)
        XCTAssertEqual(cmake?.command, "brew install cmake")
        XCTAssertEqual(cmake?.manual, false)
        XCTAssertEqual(cmake?.title, "CMake")
    }

    func testRustupStaysDisplayOnly() {
        let rows = SetupRows.rows(tools: tools(missing: ["rustup"]), developerMode: true)
        XCTAssertEqual(rows.first { $0.name == "rustup" }?.manual, true)
    }

    func testUnknownToolsAreDropped() {
        let extra = tools() + [SetupTool(name: "taplo", installed: false, command: nil, manual: false)]
        let rows = SetupRows.rows(tools: extra, developerMode: true)
        XCTAssertNil(rows.first { $0.name == "taplo" })
    }

    func testMissingReportDropsTheRow() {
        let rows = SetupRows.rows(tools: [], developerMode: false)
        XCTAssertEqual(rows.map(\.name), [SetupRows.debuggingName])
    }
}
