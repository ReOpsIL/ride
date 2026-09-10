import XCTest

final class BracketPairingTests: XCTestCase {
    func testOpenersPairBeforeNothingWhitespaceOrClosers() {
        XCTAssertEqual(type("(", "foo|"), .insertPair(")"))
        XCTAssertEqual(type("[", "a| b"), .insertPair("]"))
        XCTAssertEqual(type("{", "f(|)"), .insertPair("}"))
        XCTAssertEqual(type("(", "a|;"), .insertPair(")"))
        XCTAssertEqual(type("(", "a|b"), .none)
    }

    func testClosersTypeOverTheirTwin() {
        XCTAssertEqual(type(")", "f(|)"), .typeOver)
        XCTAssertEqual(type("]", "f(|)"), .none)
        XCTAssertEqual(type("}", "a|"), .none)
        XCTAssertEqual(type("\"", "\"|\""), .typeOver)
    }

    func testSelectionsGetWrapped() {
        XCTAssertEqual(type("(", "[ab]"), .wrap(open: "(", close: ")"))
        XCTAssertEqual(type("\"", "x[ab]y"), .wrap(open: "\"", close: "\""))
        XCTAssertEqual(type(")", "[ab]"), .none)
    }

    func testQuotesRespectIdentifiersEscapesAndRustLifetimes() {
        XCTAssertEqual(type("\"", "x = |"), .insertPair("\""))
        XCTAssertEqual(type("\"", "don|"), .none)
        XCTAssertEqual(type("\"", "\\|"), .none)
        XCTAssertEqual(type("'", "x = |"), .none)
        XCTAssertEqual(type("'", "x = |", .c), .insertPair("'"))
        XCTAssertEqual(type("'", "'|'", .c), .typeOver)
        XCTAssertEqual(type("'", "'|'"), .none)
    }

    func testBackspaceDeletesAnEmptyPair() {
        XCTAssertTrue(BracketPairing.deletesPair("()", caret: 1))
        XCTAssertTrue(BracketPairing.deletesPair("\"\"", caret: 1))
        XCTAssertTrue(BracketPairing.deletesPair("[]", caret: 1))
        XCTAssertFalse(BracketPairing.deletesPair("(a)", caret: 1))
        XCTAssertFalse(BracketPairing.deletesPair("()", caret: 0))
        XCTAssertFalse(BracketPairing.deletesPair("()", caret: 2))
        XCTAssertFalse(BracketPairing.deletesPair("", caret: 0))
    }

    private func type(_ typed: String, _ fixture: String, _ language: BufferLanguage = .rust) -> PairAction {
        let (text, selection) = Fixture.parse(fixture)
        return BracketPairing.onType(typed, text: text, selection: selection, language: language)
    }
}
