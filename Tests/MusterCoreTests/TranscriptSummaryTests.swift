import XCTest
@testable import MusterCore

final class TranscriptSummaryTests: XCTestCase {
    let reader = TranscriptReader()

    func testExtractsTitleCwdBranchModelAndPrompt() {
        let jsonl = [
            #"{"type":"ai-title","aiTitle":"Fix the bug"}"#,
            #"{"type":"user","gitBranch":"main","cwd":"/Users/jlk/Projects/muster","message":{"role":"user","content":"fix the notification bug"}}"#,
            #"{"type":"assistant","gitBranch":"main","message":{"role":"assistant","model":"claude-opus-4-8","content":[{"type":"text","text":"ok"}]}}"#,
        ].joined(separator: "\n")
        let s = reader.summarize(jsonl)
        XCTAssertEqual(s.title, "Fix the bug")
        XCTAssertEqual(s.cwd, "/Users/jlk/Projects/muster")
        XCTAssertEqual(s.gitBranch, "main")
        XCTAssertEqual(s.model, "claude-opus-4-8")
        XCTAssertEqual(s.lastPrompt, "fix the notification bug")
    }

    func testLastPromptRecordWinsOverUserText() {
        let jsonl = [
            #"{"type":"user","message":{"role":"user","content":"first"}}"#,
            #"{"type":"last-prompt","lastPrompt":"the real current prompt","leafUuid":"x"}"#,
        ].joined(separator: "\n")
        XCTAssertEqual(reader.summarize(jsonl).lastPrompt, "the real current prompt")
    }

    func testHeadBranchResolvesToWorktreeBranch() {
        let jsonl = [
            #"{"type":"assistant","gitBranch":"HEAD","message":{"role":"assistant","model":"claude-sonnet-5","content":[]}}"#,
            #"{"type":"worktree-state","worktreeSession":{"worktreeBranch":"feat/x","worktreePath":"/w"}}"#,
        ].joined(separator: "\n")
        XCTAssertEqual(reader.summarize(jsonl).gitBranch, "feat/x")
    }

    func testMetaUserPromptIsSkipped() {
        let jsonl = [
            #"{"type":"user","message":{"role":"user","content":"real ask"}}"#,
            #"{"type":"user","isMeta":true,"message":{"role":"user","content":"<system-reminder>noise</system-reminder>"}}"#,
        ].joined(separator: "\n")
        XCTAssertEqual(reader.summarize(jsonl).lastPrompt, "real ask")
    }

    func testEmptyAndGarbageTolerated() {
        XCTAssertEqual(reader.summarize(""), TranscriptSummary())
        XCTAssertEqual(reader.summarize("not json\n{bad"), TranscriptSummary())
    }
}
