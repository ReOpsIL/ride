import XCTest

final class RunOutputBufferTests: XCTestCase {
    func testSequenceGrowsWithAppends() {
        var buffer = RunOutputBuffer(maxLines: 4, dropChunk: 2)
        for index in 1...4 {
            buffer.append("\(index)")
        }
        XCTAssertEqual(buffer.first, 0)
        XCTAssertEqual(buffer.end, 4)
    }

    func testRollingDropsAChunkAndMovesFirst() {
        var buffer = RunOutputBuffer(maxLines: 4, dropChunk: 2)
        for index in 1...7 {
            buffer.append("\(index)")
        }
        XCTAssertEqual(buffer.first, 2)
        XCTAssertEqual(buffer.end, 7)
        XCTAssertEqual(buffer.lines.first, "3")
        XCTAssertEqual(buffer.last, "7")
    }

    func testClearResetsSequence() {
        var buffer = RunOutputBuffer(maxLines: 4, dropChunk: 2)
        for index in 1...7 {
            buffer.append("\(index)")
        }
        buffer.clear()
        XCTAssertEqual(buffer.first, 0)
        XCTAssertEqual(buffer.end, 0)
        XCTAssertTrue(buffer.lines.isEmpty)
    }

    func testPlanAppendsOnlyNewLines() {
        let plan = RunOutputAppend.plan(first: 0, end: 10, rendered: 4, storedFirst: 0, restyle: false)
        XCTAssertEqual(plan, RunOutputAppend.Plan(reset: false, dropLines: 0, appendFrom: 4, rendered: 10))
    }

    func testPlanDropsWhatTheModelDropped() {
        let plan = RunOutputAppend.plan(first: 500, end: 5500, rendered: 5000, storedFirst: 0, restyle: false)
        XCTAssertEqual(plan, RunOutputAppend.Plan(reset: false, dropLines: 500, appendFrom: 4500, rendered: 5500))
    }

    func testPlanKeepsAppendingAfterTheCapIsReached() {
        var rendered = 0
        var storedFirst = 0
        var appended = 0
        var buffer = RunOutputBuffer(maxLines: 4, dropChunk: 2)
        for index in 1...12 {
            buffer.append("\(index)")
            let plan = RunOutputAppend.plan(
                first: buffer.first,
                end: buffer.end,
                rendered: rendered,
                storedFirst: storedFirst,
                restyle: false
            )
            XCTAssertFalse(plan.reset)
            storedFirst += plan.dropLines
            appended += buffer.lines.count - plan.appendFrom
            rendered = plan.rendered
        }
        XCTAssertEqual(appended, 12)
        XCTAssertEqual(rendered, 12)
        XCTAssertEqual(storedFirst, buffer.first)
    }

    func testPlanResetsOnRestyleAndOnClear() {
        XCTAssertTrue(RunOutputAppend.plan(first: 0, end: 3, rendered: 3, storedFirst: 0, restyle: true).reset)
        XCTAssertEqual(
            RunOutputAppend.plan(first: 0, end: 0, rendered: 7, storedFirst: 0, restyle: false),
            RunOutputAppend.Plan(reset: true, dropLines: 0, appendFrom: 0, rendered: 0)
        )
    }
}
