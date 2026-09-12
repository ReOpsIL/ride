import XCTest

final class DebugLoadStateTests: XCTestCase {
    func testMatchingGenerationIsApplied() {
        var state = DebugLoadState()
        guard let generation = state.begin("threads") else {
            return XCTFail("first load was coalesced")
        }
        XCTAssertTrue(state.finish("threads", generation: generation))
        XCTAssertEqual(state.pending, 0)
    }

    func testOldGenerationIsDropped() {
        var state = DebugLoadState()
        guard let generation = state.begin("threads") else {
            return XCTFail("first load was coalesced")
        }
        state.invalidate()
        XCTAssertFalse(state.isCurrent(generation))
        XCTAssertFalse(state.finish("threads", generation: generation))
    }

    func testDuplicateKeyIsCoalescedUntilItFinishes() {
        var state = DebugLoadState()
        guard let generation = state.begin("scopes.1") else {
            return XCTFail("first load was coalesced")
        }
        XCTAssertNil(state.begin("scopes.1"))
        XCTAssertNotNil(state.begin("scopes.2"))
        XCTAssertTrue(state.finish("scopes.1", generation: generation))
        XCTAssertNotNil(state.begin("scopes.1"))
    }

    func testInvalidateClearsInFlightSoABurstOfStopsReloads() {
        var state = DebugLoadState()
        XCTAssertNotNil(state.begin("threads"))
        let first = state.invalidate()
        XCTAssertEqual(state.pending, 0)
        XCTAssertFalse(state.isInFlight("threads"))
        XCTAssertEqual(state.begin("threads"), first)
        let second = state.invalidate()
        XCTAssertEqual(second, first + 1)
        XCTAssertTrue(state.isCurrent(second))
    }
}
