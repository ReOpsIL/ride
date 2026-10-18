import XCTest

final class OverlayModelTests: XCTestCase {
    func testE0382MatchesTheMock() {
        let map = OverlaySourceMap(Self.source)
        let binding = map.range(of: "rows", occurrence: 1)
        let moved = map.range(of: "rows", occurrence: 2)
        let borrowed = map.range(of: "rows", occurrence: 4)
        let function = map.range(of: "sum_by_key", occurrence: 2)
        let parameter = map.range(of: "rows", occurrence: 5)
        XCTAssertEqual(map.line(at: binding.location), 5)
        XCTAssertEqual(map.line(at: borrowed.location), 7)
        XCTAssertEqual(map.line(at: function.location), 10)
        let item = e0382(map, binding: binding, moved: moved, borrowed: borrowed, function: function, parameter: parameter)
        let layout = placed(item, lineAt: map.line(at:), lineStart: map.lineStart)
        XCTAssertEqual(layout.numbers.map(\.number), [1, 2, 3])
        XCTAssertEqual(layout.numbers.map(\.line), [5, 6, 7])
        XCTAssertEqual(layout.numbers.map(\.kind), [.secondary, .secondary, .primary])
        XCTAssertEqual(layout.rows[5]?.first?.chips.first?.text, Self.move)
        XCTAssertEqual(layout.rows[6]?.first?.chips.first?.text, "value moved here")
        XCTAssertEqual(layout.rows[7]?.first?.chips.first?.text, "value borrowed here after move")
        XCTAssertEqual(layout.primaryLine, 7)
        XCTAssertEqual(layout.notes.count, 2)
        XCTAssertEqual(layout.notes[0].level, .note)
        XCTAssertEqual(layout.notes[0].jumpLine, 10)
        XCTAssertTrue(layout.notes[0].message.hasPrefix("consider changing"))
        XCTAssertEqual(layout.notes[1].level, .help)
        XCTAssertEqual(layout.notes[1].fixTitle, "consider cloning the value if the performance cost is acceptable")
        XCTAssertTrue(layout.showsFix)
        let noteChips = layout.rows[10]?.flatMap(\.chips) ?? []
        XCTAssertEqual(noteChips.map(\.text), ["in this function", "this parameter takes ownership of the value"])
    }

    func testOverlapPacksOntoTheNextRow() {
        let item = pair(primary: (0, 1, "abcd"), secondary: (4, 6, "xy"))
        let rows = placed(item, lineAt: { _ in 1 }, lineStart: { _ in 0 }, width: { CGFloat($0.count + 2) }).rows[1] ?? []
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map { $0.chips.map(\.offset) }, [[0], [4]])
    }

    func testSeparatedChipsShareARow() {
        let item = pair(primary: (0, 1, "ab"), secondary: (10, 12, "cd"))
        let rows = placed(item, lineAt: { _ in 1 }, lineStart: { _ in 0 }, width: { CGFloat($0.count + 2) }).rows[1] ?? []
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].chips.map(\.offset), [0, 10])
    }

    func testExternalChipUsesThePrimaryLine() {
        var item = pair(primary: (0, 2, "here"), secondary: (0, 1, "elsewhere"))
        item.secondary[0].path = "/std/lib.rs"
        item.secondary[0].lineStart = 12
        let layout = placed(item, lineAt: { _ in 4 }, lineStart: { _ in 0 })
        let chips = layout.rows[4]?.flatMap(\.chips) ?? []
        XCTAssertEqual(chips.first { $0.kind == .external }?.text, "elsewhere ↗ lib.rs:12")
        XCTAssertEqual(layout.numbers.count, 0)
    }

    func testFoldedSpanAttachesToTheVisibleLine() {
        let item = pair(primary: (0, 2, "top"), secondary: (100, 104, "folded"))
        let lineAt: (Int) -> Int = { $0 >= 100 ? 10 : 1 }
        let lineStart: (Int) -> Int = { $0 == 10 ? 100 : 0 }
        let layout = placed(item, lineAt: lineAt, lineStart: lineStart, visibleLine: { $0 == 10 ? 4 : $0 })
        XCTAssertEqual(layout.rows[4]?.first?.chips.map(\.text), ["folded"])
        XCTAssertEqual(layout.numbers.map(\.number), [1, 2])
        XCTAssertEqual(layout.numbers.map(\.line), [1, 4])
    }

    func testMacroNameSuffixAndASingleSpanHasNoNumber() {
        var item = pair(primary: (0, 4, "inside"), secondary: nil)
        item.primary.macroName = "println!"
        let layout = placed(item, lineAt: { _ in 1 }, lineStart: { _ in 0 })
        XCTAssertEqual(layout.rows[1]?.first?.chips.first?.text, "inside in println!")
        XCTAssertTrue(layout.numbers.isEmpty)
    }

    private func placed(
        _ item: StoredDiagnostic,
        lineAt: @escaping (Int) -> Int,
        lineStart: @escaping (Int) -> Int,
        utf16: @escaping (Int) -> Int = { $0 },
        visibleLine: @escaping (Int) -> Int = { $0 },
        width: @escaping (String) -> CGFloat = { CGFloat($0.count) }
    ) -> OverlayLayout {
        OverlayModel.place(
            item,
            lineAt: lineAt,
            lineStart: lineStart,
            utf16: utf16,
            visibleLine: visibleLine,
            x: { CGFloat($0) },
            width: width
        )
    }

    private func e0382(
        _ map: OverlaySourceMap,
        binding: NSRange,
        moved: NSRange,
        borrowed: NSRange,
        function: NSRange,
        parameter: NSRange
    ) -> StoredDiagnostic {
        let primary = map.label("main.rs", borrowed, "value borrowed here after move")
        let secondary = [
            map.label("main.rs", binding, Self.move),
            map.label("main.rs", moved, "value moved here"),
        ]
        let note = StoredNote(
            level: .note,
            message: "consider changing this parameter type in function `sum_by_key` to borrow instead if owning the value isn't necessary",
            labels: [
                map.label("main.rs", function, "in this function"),
                map.label("main.rs", parameter, "this parameter takes ownership of the value"),
            ]
        )
        let help = StoredNote(
            level: .help,
            message: "consider cloning the value if the performance cost is acceptable",
            labels: []
        )
        let fix = StoredFix(title: help.message, edits: [StoredEdit(startByte: 0, endByte: 0, text: ".clone()", caretByte: 0)])
        return StoredDiagnostic(
            primary: primary,
            level: .error,
            message: "borrow of moved value: `rows`",
            code: "E0382",
            fixes: [fix],
            secondary: secondary,
            notes: [note, help]
        )
    }

    private func pair(primary: (Int, Int, String), secondary: (Int, Int, String)?) -> StoredDiagnostic {
        StoredDiagnostic(
            primary: plain("main.rs", primary.0, primary.1, primary.2),
            level: .error,
            message: "m",
            code: nil,
            secondary: secondary.map { [plain("main.rs", $0.0, $0.1, $0.2)] } ?? []
        )
    }

    private func plain(_ path: String, _ start: Int, _ end: Int, _ text: String) -> StoredLabel {
        StoredLabel(path: path, byteStart: UInt32(start), byteEnd: UInt32(end), lineStart: 1, lineEnd: 1, column: 1, text: text, macroName: nil)
    }

    private static let move = "move occurs because `rows` has type `Vec<&str>`, which does not implement the `Copy` trait"

    private static let source = """
    use std::collections::HashMap;

    fn main() {
        let text = String::from("a,1\\nb,2");
        let rows: Vec<&str> = text.lines().collect();
        let totals = sum_by_key(rows);
        println!("{} rows, {} keys", rows.len(), totals.len());
    }

    fn sum_by_key(rows: Vec<&str>) -> HashMap<String, f64> {
        0
    }
    """
}
