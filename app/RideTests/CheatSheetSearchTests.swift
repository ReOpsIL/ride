import XCTest

final class CheatSheetSearchTests: XCTestCase {
    private let groups = [
        CheatGroup(title: "Functions", matched: true, items: [
            CheatItem(name: "fn where clause", doc: "Define a generic function with its bounds.", snippet: "fn name<T>() where T: Clone {}"),
            CheatItem(name: "fn with lifetime", doc: "Define a function whose result borrows.", snippet: "fn name<'a>(x: &'a str) -> &'a str {}"),
        ]),
        CheatGroup(title: "Structs", matched: false, items: [
            CheatItem(name: "tuple struct", doc: "Define a struct with positional fields.", snippet: "struct Name(pub Type);"),
        ]),
    ]

    private func rows(_ query: String) -> [CheatRow] {
        var search = PopupSearch()
        search.type(query)
        return CheatSheetRows.rows(groups, search: search)
    }

    func testEmptySearchKeepsEveryRow() {
        XCTAssertEqual(CheatSheetRows.rows(groups, search: PopupSearch()), CheatSheetRows.rows(groups))
    }

    func testSearchesDocsAndSnippetsAndDropsEmptyGroups() {
        XCTAssertEqual(rows("borrows").compactMap(\.entry?.name), ["fn with lifetime"])
        XCTAssertEqual(rows("clone"), [.header(title: "Functions", matched: true), .entry(groups[0].items[0])])
        XCTAssertEqual(rows("positional").first, .header(title: "Structs", matched: false))
    }

    func testGroupTitleMatchesItsItems() {
        XCTAssertEqual(rows("structs").compactMap(\.entry?.name), ["tuple struct"])
    }

    func testNothingMatchesGivesNoRows() {
        XCTAssertEqual(rows("zzz"), [])
    }
}
