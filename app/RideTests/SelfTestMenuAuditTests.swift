import XCTest

final class SelfTestMenuAuditTests: XCTestCase {
    private func audit(claims: [String: [String]], exempt: [String: String] = [:], passed: Set<String> = ["open file"]) -> SelfTestMenuAudit {
        SelfTestMenuAudit(
            paths: ["File › Open…", "File › Close Editor", "Window › Minimize"],
            claims: claims,
            exempt: exempt,
            known: ["open file", "close editor", "other suite step"],
            suite: ["open file", "close editor"],
            passed: passed
        )
    }

    func testEveryItemNeedsAClaimOrAnExemption() {
        let result = audit(claims: ["File › Open…": ["open file"]], exempt: ["Window › Minimize": "system"])
        XCTAssertEqual(result.problems, ["uncovered File › Close Editor"])
    }

    func testClaimsMustNameKnownStepsThatPassedInThisSuite() {
        let result = audit(claims: [
            "File › Open…": ["open file", "typo step"],
            "File › Close Editor": ["close editor"],
            "Window › Minimize": ["other suite step"],
        ])
        XCTAssertEqual(result.problems, [
            "File › Open… claims unknown step 'typo step'",
            "File › Close Editor step 'close editor' did not pass",
        ])
    }

    func testListingMarksEachItemAndReportsAbsentEntries() {
        let result = audit(claims: ["File › Open…": ["open file"], "File › Gone": ["open file"]], exempt: ["Window › Minimize": "system"])
        XCTAssertEqual(result.stale, ["File › Gone"])
        XCTAssertTrue(result.listing.contains("COVERED File › Open… <- open file"))
        XCTAssertTrue(result.listing.contains("MISSING File › Close Editor"))
        XCTAssertTrue(result.listing.contains("EXEMPT  Window › Minimize (system)"))
        XCTAssertTrue(result.listing.contains("ABSENT  File › Gone"))
    }
}
