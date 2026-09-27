import XCTest

final class KeyComboTests: XCTestCase {
    func testGlyphsParseModifiersInAnyOrder() {
        XCTAssertEqual(KeyCombo(glyphs: "⇧⌥⌘O"), KeyCombo(key: "o", modifiers: [.shift, .option, .command]))
        XCTAssertEqual(KeyCombo(glyphs: "⌃Space")?.key, "space")
        XCTAssertEqual(KeyCombo(glyphs: "⇧F6"), KeyCombo(key: "F6", modifiers: .shift))
        XCTAssertEqual(KeyCombo(glyphs: "⌥esc")?.key, "escape")
        XCTAssertEqual(KeyCombo(glyphs: "⌘L")?.modifiers, .command)
    }

    func testDescriptionUsesAppleModifierOrder() {
        XCTAssertEqual(KeyCombo(key: "o", modifiers: [.command, .shift, .option]).description, "⌥⇧⌘O")
        XCTAssertEqual(KeyCombo(key: "minus", modifiers: .command).description, "⌘−")
        XCTAssertEqual(KeyCombo(key: "up", modifiers: [.control, .option]).description, "⌃⌥↑")
    }

    func testMenuKeyEquivalentsNormalise() {
        XCTAssertEqual(KeyCombo(keyEquivalent: "L", modifiers: .command), KeyCombo(glyphs: "⇧⌘L"))
        XCTAssertEqual(KeyCombo(keyEquivalent: "\u{8}", modifiers: .command), KeyCombo(glyphs: "⌘⌫"))
        XCTAssertEqual(KeyCombo(keyEquivalent: "\u{7F}", modifiers: .command), KeyCombo(glyphs: "⌘⌫"))
        XCTAssertEqual(KeyCombo(keyEquivalent: "\r", modifiers: .option), KeyCombo(glyphs: "⌥↩"))
        XCTAssertEqual(KeyCombo(keyEquivalent: "\u{F70F}", modifiers: []), KeyCombo(glyphs: "F12"))
        XCTAssertEqual(KeyCombo(keyEquivalent: "\u{F700}", modifiers: .control), KeyCombo(glyphs: "⌃↑"))
        XCTAssertEqual(KeyCombo(keyEquivalent: "-", modifiers: .command), KeyCombo(glyphs: "⌘−"))
        XCTAssertNil(KeyCombo(keyEquivalent: "", modifiers: .command))
    }
}
