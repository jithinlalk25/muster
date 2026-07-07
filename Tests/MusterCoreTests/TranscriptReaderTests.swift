import XCTest
@testable import MusterCore

final class TranscriptReaderTests: XCTestCase {
    // Mirrors real record shapes verified against on-disk transcripts.
    let sample = [
        #"{"type":"attachment","cwd":"/Users/jlk/Projects/muster","sessionId":"s1"}"#,
        #"{"type":"ai-title","aiTitle":"First title","sessionId":"s1"}"#,
        #"{"type":"user","cwd":"/Users/jlk/Projects/muster","message":{"role":"user","content":"hello there"}}"#,
        #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"hmm"},{"type":"text","text":"hi!"},{"type":"tool_use","name":"Bash","input":{}}]}}"#,
        #"{"type":"ai-title","aiTitle":"Latest title","sessionId":"s1"}"#,
    ].joined(separator: "\n")

    func testTitleIsLatestAiTitle() {
        let (_, title) = TranscriptReader().parse(sample)
        XCTAssertEqual(title, "Latest title")
    }

    func testMessagesExtracted() {
        let (messages, _) = TranscriptReader().parse(sample)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], .init(role: .user, text: "hello there"))
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[1].text, "hi!\n[tool: Bash]")
    }

    func testFirstCwd() {
        XCTAssertEqual(TranscriptReader().firstCwd(sample), "/Users/jlk/Projects/muster")
    }

    func testEmptyAndGarbageTolerated() {
        let (messages, title) = TranscriptReader().parse("not json\n\n{}")
        XCTAssertTrue(messages.isEmpty)
        XCTAssertNil(title)
    }

    func testToolResultRendered() {
        let t = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_result","content":"ok"}]}}"#
        let (messages, _) = TranscriptReader().parse(t)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].text, "[tool result]")
    }

    func testThinkingOnlyMessageDropped() {
        let t = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"hmm"}]}}"#
        let (messages, _) = TranscriptReader().parse(t)
        XCTAssertTrue(messages.isEmpty)
    }

    func testMissingRoleFallsBackToOther() {
        let t = #"{"type":"user","message":{"content":"hi"}}"#
        let (messages, _) = TranscriptReader().parse(t)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].role, .other)
    }
}
