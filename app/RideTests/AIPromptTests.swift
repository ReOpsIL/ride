import XCTest

final class AIPromptTests: XCTestCase {
    func testUserPromptMarksCaretAndListsExtras() {
        let input = AIPromptInput(
            language: "Rust",
            path: "src/main.rs",
            prefix: "fn main() {\n    let x = ",
            suffix: ";\n}\n",
            extras: [AIExtraFile(path: "src/util.rs", text: "pub fn f() {}")]
        )
        let prompt = AIPrompt.user(input)
        XCTAssertTrue(prompt.contains("let x = <|cursor|>;"))
        XCTAssertTrue(prompt.hasPrefix("<file path=\"src/util.rs\">\npub fn f() {}\n</file>"))
        XCTAssertTrue(prompt.contains("path=\"src/main.rs\" language=\"Rust\" editing=\"true\""))
    }

    func testParserAcceptsObjectArrayAndFencedJSON() {
        let object = "{\"suggestions\":[{\"label\":\"call\",\"text\":\"foo()\"},{\"label\":\"\",\"text\":\"\"}]}"
        XCTAssertEqual(AIResponseParser.suggestions(in: object), [AISuggestion(text: "foo()", label: "call")])
        XCTAssertEqual(AIResponseParser.suggestions(in: "[{\"text\":\"a\"}]"), [AISuggestion(text: "a", label: "")])
        let fenced = "Here you go:\n```json\n{\"suggestions\":[{\"label\":\"x\",\"text\":\"1 + 1\"}]}\n```"
        XCTAssertEqual(AIResponseParser.suggestions(in: fenced).map(\.text), ["1 + 1"])
        XCTAssertEqual(AIResponseParser.suggestions(in: "no json here"), [])
    }

    func testSuggestionNameIsFirstNonEmptyLineOrLabel() {
        XCTAssertEqual(AISuggestion(text: "\n  let y = 2;\n  y\n", label: "assign").name, "let y = 2;")
        XCTAssertEqual(AISuggestion(text: "   ", label: "spaces").name, "spaces")
    }

    func testClipKeepsTailOfPrefixAndHeadOfSuffixOnLineBoundaries() {
        let prefix = (1...200).map { "line \($0)" }.joined(separator: "\n")
        let suffix = (1...200).map { "after \($0)" }.joined(separator: "\n")
        let clipped = AIContextWindow.clip(prefix: AIContextWindow.tail(prefix, limit: 60), suffix: AIContextWindow.head(suffix, limit: 40))
        XCTAssertTrue(clipped.prefix.hasPrefix("line "))
        XCTAssertTrue(clipped.prefix.hasSuffix("line 200"))
        XCTAssertLessThanOrEqual(clipped.prefix.count, 60)
        XCTAssertTrue(clipped.suffix.hasPrefix("after 1\n"))
        XCTAssertFalse(clipped.suffix.hasSuffix("\n"))
        XCTAssertEqual(AIContextWindow.head("short", limit: 100), "short")
    }

    func testConfigFallsBackToDefaults() {
        let config = AIConfig(provider: "openrouter", model: "  ", auth: "bogus", level: "project")
        XCTAssertEqual(config.provider, .openrouter)
        XCTAssertEqual(config.model, "anthropic/claude-haiku-4.5")
        XCTAssertEqual(config.auth, .login)
        XCTAssertEqual(config.level, .project)
        XCTAssertEqual(AIConfig(provider: "", model: "", auth: "", level: "").model, "claude-haiku-4-5")
        XCTAssertEqual(AIConfig(provider: "anthropic", model: " claude-opus-5 ", auth: "key", level: "file").model, "claude-opus-5")
    }

    func testDefaultModelIsTheFirstPresetOfEachProvider() {
        for provider in AIProvider.allCases {
            XCTAssertEqual(provider.defaultModel, provider.presets[0].id)
            XCTAssertEqual(Set(provider.presets.map(\.id)).count, provider.presets.count)
        }
    }

    func testModelChoiceMapsStoredModelToPickerSelection() {
        XCTAssertEqual(AIModelChoice.selection(model: "", provider: .anthropic, editingCustom: false), "claude-haiku-4-5")
        XCTAssertEqual(AIModelChoice.selection(model: "claude-opus-5", provider: .anthropic, editingCustom: false), "claude-opus-5")
        XCTAssertEqual(AIModelChoice.selection(model: "deepseek/deepseek-coder", provider: .openrouter, editingCustom: false), AIModelChoice.custom)
        XCTAssertEqual(AIModelChoice.selection(model: "claude-opus-5", provider: .anthropic, editingCustom: true), AIModelChoice.custom)
    }

    func testOutcomeText() {
        XCTAssertEqual(AIOutcome.text(count: 0, shown: false), "AI: no suggestion")
        XCTAssertEqual(AIOutcome.text(count: 1, shown: true), "AI: 1 suggestion")
        XCTAssertEqual(AIOutcome.text(count: 3, shown: false), "AI: 3 suggestions (caret moved)")
    }
}
