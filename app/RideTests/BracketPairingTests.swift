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

    func testPairPositionsForNestedRoundSquareCurlyAndAngle() {
        XCTAssertEqual(pair("(x)", 0), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("(x)", 1), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("(x)", 2), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("(x)", 3), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("[x]", 0), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("[x]", 3), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("{x}", 0), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("{x}", 3), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("<x>", 0), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("<x>", 3), BracketMatch(open: 0, close: 2))
        XCTAssertEqual(pair("f(g(x))", 3), BracketMatch(open: 3, close: 5))
        XCTAssertEqual(pair("f(g(x))", 1), BracketMatch(open: 1, close: 6))
        XCTAssertEqual(pair("f(g(x))", 5), BracketMatch(open: 3, close: 5))
        XCTAssertEqual(pair("f(g(x))", 6), BracketMatch(open: 1, close: 6))
        XCTAssertEqual(pair("f(g(x))", 7), BracketMatch(open: 1, close: 6))
        XCTAssertEqual(pair("a[b[c]]", 3), BracketMatch(open: 3, close: 5))
        XCTAssertEqual(pair("a[b[c]]", 1), BracketMatch(open: 1, close: 6))
        XCTAssertEqual(pair("a{b{c}}", 3), BracketMatch(open: 3, close: 5))
        XCTAssertEqual(pair("a{b{c}}", 1), BracketMatch(open: 1, close: 6))
        XCTAssertEqual(pair("Vec<Map<K, V>>", 3), BracketMatch(open: 3, close: 13))
        XCTAssertEqual(pair("Vec<Map<K, V>>", 7), BracketMatch(open: 7, close: 12))
        XCTAssertEqual(pair("Vec<Map<K, V>>", 12), BracketMatch(open: 7, close: 12))
        XCTAssertEqual(pair("Vec<Map<K, V>>", 13), BracketMatch(open: 3, close: 13))
        XCTAssertEqual(pair("Vec<Map<K, V>>", 14), BracketMatch(open: 3, close: 13))
    }

    func testUnmatchedPairIsNil() {
        XCTAssertNil(pair("(x", 0))
        XCTAssertNil(pair("x)", 1))
        XCTAssertNil(pair("x)", 2))
        XCTAssertNil(pair("(]", 0))
        XCTAssertNil(pair("[)", 0))
        XCTAssertNil(pair("{x", 0))
        XCTAssertNil(pair("<x", 0))
        XCTAssertNil(pair("x>", 1))
        XCTAssertNil(pair("foo", 1))
        XCTAssertNil(pair("x", 0))
        XCTAssertNil(pair("", 0))
        XCTAssertNil(pair("((x)", 0))
        XCTAssertNil(pair("(x))", 4))
    }

    private func type(_ typed: String, _ fixture: String, _ language: BufferLanguage = .rust) -> PairAction {
        let (text, selection) = Fixture.parse(fixture)
        return BracketPairing.onType(typed, text: text, selection: selection, language: language)
    }

    private func pair(_ text: String, _ caret: Int) -> BracketMatch? {
        BracketPairing.pair(in: text, caret: caret)
    }
}
