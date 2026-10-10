import XCTest

final class MarkdownPageTests: XCTestCase {
    func testMatchesMarkdownExtensions() {
        XCTAssertTrue(MarkdownPage.matches(URL(fileURLWithPath: "/a/Readme.MD")))
        XCTAssertTrue(MarkdownPage.matches(URL(fileURLWithPath: "/a/notes.markdown")))
        XCTAssertFalse(MarkdownPage.matches(URL(fileURLWithPath: "/a/page.html")))
        XCTAssertFalse(MarkdownPage.matches(URL(fileURLWithPath: "/a/main.rs")))
        XCTAssertFalse(MarkdownPage.matches(URL(fileURLWithPath: "/a/readme.mdown")))
        XCTAssertFalse(MarkdownPage.matches(nil))
    }
}
