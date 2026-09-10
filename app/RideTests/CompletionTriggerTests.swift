import XCTest

final class CompletionTriggerTests: XCTestCase {
    private func gate(_ language: BufferLanguage, _ line: String, _ inserted: String? = nil) -> CompletionTrigger? {
        CompletionTriggerGate.trigger(language: language, line: line, inserted: inserted ?? String(line.last!))
    }

    func testIdentifierCharacters() {
        XCTAssertEqual(gate(.rust, "let co"), .identifier)
        XCTAssertEqual(gate(.rust, "x_"), .identifier)
        XCTAssertEqual(gate(.rust, "x1"), .identifier)
        XCTAssertNil(gate(.rust, "let x = 1"))
        XCTAssertEqual(gate(.toml, "[dep"), .identifier)
        XCTAssertEqual(gate(.make, "all: $(OB"), .identifier)
        XCTAssertEqual(gate(.cmake, "add_exe"), .identifier)
    }

    func testRustTriggers() {
        XCTAssertEqual(gate(.rust, "foo."), .trigger)
        XCTAssertNil(gate(.rust, "0.."))
        XCTAssertEqual(gate(.rust, "std::"), .trigger)
        XCTAssertNil(gate(.rust, "a:"))
        XCTAssertEqual(gate(.rust, "use "), .trigger)
        XCTAssertEqual(gate(.rust, "    pub use "), .trigger)
        XCTAssertNil(gate(.rust, "fuse "))
        XCTAssertNil(gate(.rust, "let x "))
        XCTAssertEqual(gate(.rust, "#"), .trigger)
        XCTAssertEqual(gate(.rust, "#[derive("), .trigger)
        XCTAssertNil(gate(.rust, "foo("))
    }

    func testCTriggers() {
        XCTAssertEqual(gate(.c, "p->"), .trigger)
        XCTAssertEqual(gate(.c, "s."), .trigger)
        XCTAssertEqual(gate(.cpp, "std::"), .trigger)
        XCTAssertEqual(gate(.c, "#"), .trigger)
        XCTAssertEqual(gate(.c, "  #"), .trigger)
        XCTAssertNil(gate(.c, "a #"))
        XCTAssertEqual(gate(.c, "#include <"), .trigger)
        XCTAssertEqual(gate(.cpp, "# include \""), .trigger)
        XCTAssertEqual(gate(.c, "#include <sys/"), .trigger)
        XCTAssertEqual(gate(.c, "#include \"../"), .trigger)
        XCTAssertNil(gate(.c, "#include <sys/types.h>/"))
        XCTAssertNil(gate(.c, "if (a <"))
        XCTAssertNil(gate(.c, "a /"))
        XCTAssertNil(gate(.c, "#include_next <"))
    }

    func testConfigLanguagesHaveNoTriggerCharacters() {
        XCTAssertNil(gate(.toml, "a."))
        XCTAssertNil(gate(.cmake, "a::"))
        XCTAssertNil(gate(.make, "#"))
    }

    func testLanguagesWithoutCompletions() {
        XCTAssertNil(gate(.markdown, "wor"))
        XCTAssertNil(gate(.plain, "wor"))
    }

    func testPastesAndWhitespaceNeverTrigger() {
        XCTAssertNil(gate(.rust, "foo.bar", "foo.bar"))
        XCTAssertNil(gate(.rust, "foo\n", "\n"))
        XCTAssertNil(gate(.rust, "foo ", " "))
        XCTAssertNil(gate(.rust, "foo", ""))
    }
}
