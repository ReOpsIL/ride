import XCTest

final class DebugLoadStateTests: XCTestCase {
    func testMatchingGenerationIsApplied() {
        var state = DebugLoadState()
        guard let token = state.begin("threads", scoped: false) else {
            return XCTFail("first load was coalesced")
        }
        XCTAssertTrue(state.finish("threads", token: token))
        XCTAssertNotNil(state.begin("threads", scoped: false))
    }

    func testOldGenerationIsDropped() {
        var state = DebugLoadState()
        guard let token = state.begin("threads", scoped: false) else {
            return XCTFail("first load was coalesced")
        }
        state.invalidate()
        XCTAssertFalse(state.isCurrent(token.generation))
        XCTAssertFalse(state.finish("threads", token: token))
    }

    func testDuplicateKeyIsCoalescedUntilItFinishes() {
        var state = DebugLoadState()
        guard let token = state.begin("scopes.1") else {
            return XCTFail("first load was coalesced")
        }
        XCTAssertNil(state.begin("scopes.1"))
        XCTAssertNotNil(state.begin("scopes.2"))
        XCTAssertTrue(state.finish("scopes.1", token: token))
        XCTAssertNotNil(state.begin("scopes.1"))
    }

    func testInvalidateClearsInFlightSoABurstOfStopsReloads() {
        var state = DebugLoadState()
        XCTAssertNotNil(state.begin("threads", scoped: false))
        let first = state.invalidate()
        XCTAssertEqual(state.begin("threads", scoped: false)?.generation, first)
        let second = state.invalidate()
        XCTAssertEqual(second, first + 1)
        XCTAssertTrue(state.isCurrent(second))
    }

    func testSelectingAnotherFrameDropsTheOldFramesChildren() {
        var state = DebugLoadState()
        guard let stale = state.begin("children.7.0") else {
            return XCTFail("first load was coalesced")
        }
        state.select()
        guard let fresh = state.begin("children.7.0") else {
            return XCTFail("reload after selection was coalesced")
        }
        XCTAssertFalse(state.finish("children.7.0", token: stale))
        XCTAssertNil(state.begin("children.7.0"))
        XCTAssertTrue(state.finish("children.7.0", token: fresh))
    }

    func testSelectionKeepsUnscopedLoads() {
        var state = DebugLoadState()
        guard let threads = state.begin("threads", scoped: false) else {
            return XCTFail("first load was coalesced")
        }
        state.select()
        XCTAssertNil(state.begin("threads", scoped: false))
        XCTAssertTrue(state.finish("threads", token: threads))
    }
}
