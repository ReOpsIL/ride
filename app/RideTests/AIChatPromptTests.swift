import XCTest

final class AIChatPromptTests: XCTestCase {
    func testUserTurnsCarryTheirAttachmentsBeforeTheQuestion() {
        let selection = AIChatAttachment(kind: .selection, path: "src/main.rs", line: 4, text: "let x = 1;\n", truncated: false)
        let message = AIChatMessage(role: .user, text: "Why?", attachments: [selection])
        XCTAssertEqual(
            AIChatPrompt.content(message),
            "<context kind=\"selection\" path=\"src/main.rs\" line=\"4\">\nlet x = 1;\n\n</context>\n\nWhy?"
        )
    }

    func testStreamingAndFailedMessagesAreLeftOutOfTheHistory() {
        var answer = AIChatMessage(role: .assistant, text: "partial")
        answer.streaming = true
        var failed = AIChatMessage(role: .assistant, text: "")
        failed.error = "HTTP 500"
        let turns = AIChatPrompt.turns([AIChatMessage(role: .user, text: "Q"), failed, AIChatMessage(role: .user, text: "Again"), answer])
        XCTAssertEqual(turns, [AIChatTurn(role: .user, text: "Q\n\nAgain")])
    }

    func testAttachmentLabelsShowTheLineRange() {
        let one = AIChatAttachment(kind: .selection, path: "src/a.rs", line: 7, text: "x\n", truncated: false)
        let three = AIChatAttachment(kind: .enclosing, path: "src/a.rs", line: 7, text: "a\nb\nc\n", truncated: false)
        let file = AIChatAttachment(kind: .file, path: "src/a.rs", line: 1, text: "a\nb\n", truncated: false)
        XCTAssertEqual([one.label, three.label, file.label], ["a.rs:7", "a.rs:7-9", "a.rs"])
    }

    func testTitlesComeFromTheFirstLine() {
        XCTAssertEqual(AIChatPrompt.title(for: "Explain this\nplease"), "Explain this")
        XCTAssertEqual(AIChatPrompt.title(for: "  "), "New chat")
    }
}
