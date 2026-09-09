import XCTest

final class ContrastTests: XCTestCase {
    private func palette(_ name: String) throws -> [String: Any] {
        let here = URL(fileURLWithPath: #filePath)
        let url = here.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Ride/Themes/\(name).json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func check(_ name: String) throws {
        let json = try palette(name)
        let chrome = try XCTUnwrap(json["chrome"] as? [String: String])
        let editor = try XCTUnwrap(json["editor"] as? [String: String])
        let syntax = try XCTUnwrap(json["syntax"] as? [String: String])
        for bg in ["bg.base", "bg.raised", "bg.overlay"] {
            let base = try XCTUnwrap(chrome[bg])
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(Contrast.ratio(chrome["text.primary"]!, base)), 4.5, "\(name) primary on \(bg)")
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(Contrast.ratio(chrome["text.secondary"]!, base)), 3.0, "\(name) secondary on \(bg)")
        }
        let editorBg = try XCTUnwrap(editor["background"])
        for key in ["keyword", "function", "type", "string", "comment", "variable", "number"] {
            let ratio = try XCTUnwrap(Contrast.ratio(syntax[key]!, editorBg))
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "\(name) syntax \(key)")
        }
    }

    func testDarkPalette() throws {
        try check("dark")
    }

    func testLightPalette() throws {
        try check("light")
    }

    func testRatioIsSymmetricAndBounded() {
        XCTAssertEqual(Contrast.ratio("#000000", "#FFFFFF")!, 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio("#FFFFFF", "#000000")!, 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio("#808080", "#808080")!, 1, accuracy: 0.01)
    }
}
