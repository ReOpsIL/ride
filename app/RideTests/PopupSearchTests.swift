import XCTest

final class PopupSearchTests: XCTestCase {
    private let items: [[String]] = [
        ["reserve", "fn reserve(&mut self, additional: usize)", "Reserves capacity for at least additional more elements."],
        ["with_capacity", "fn with_capacity(capacity: usize) -> Vec<T>", "Constructs a new, empty Vec with at least the specified capacity."],
        ["push", "fn push(&mut self, value: T)", "Appends an element to the back of a collection."],
        ["len", "fn len(&self) -> usize", "Returns the number of elements in the vector."],
    ]

    private func search(_ query: String) -> PopupSearch {
        var search = PopupSearch()
        search.type(query)
        return search
    }

    private func names(_ query: String) -> [String] {
        search(query).filter(items) { $0 }.map { $0[0] }
    }

    func testEmptyQueryKeepsEverything() {
        XCTAssertEqual(PopupSearch().filter(items) { $0 }.count, items.count)
        XCTAssertEqual(names("   "), ["reserve", "with_capacity", "push", "len"])
    }

    func testMatchesDocsAndSignaturesCaseInsensitively() {
        XCTAssertEqual(names("APPENDS"), ["push"])
        XCTAssertEqual(names("self) -> usize"), ["len"])
    }

    func testNameMatchesComeFirst() {
        XCTAssertEqual(names("capacity"), ["with_capacity", "reserve"])
    }

    func testEveryTermMustMatchSomewhere() {
        XCTAssertEqual(names("mut elements"), ["reserve"])
        XCTAssertEqual(names("mut nothing"), [])
    }

    func testEditingTheQuery() {
        var search = search("pushx")
        search.deleteBackward()
        XCTAssertEqual(search.query, "push")
        XCTAssertTrue(search.isActive)
        search.end()
        XCTAssertEqual(search, PopupSearch())
    }

    func testTypedRejectsControlAndFunctionKeys() {
        XCTAssertEqual(PopupSearch.typed("a"), "a")
        XCTAssertEqual(PopupSearch.typed(" "), " ")
        XCTAssertNil(PopupSearch.typed("\u{1B}"))
        XCTAssertNil(PopupSearch.typed("\u{F704}"))
        XCTAssertNil(PopupSearch.typed(""))
    }
}
