import XCTest
@testable import MusterCore

final class HookStdinParseTests: XCTestCase {
    let ts = Date(timeIntervalSince1970: 1_700_000_000)

    func testPreToolUseWithToolName() throws {
        let json = #"{"session_id":"s1","cwd":"/p/muster","transcript_path":"/t/s1.jsonl","tool_name":"Bash","hook_event_name":"PreToolUse"}"#
        let e = try HookEvent.fromClaudeStdin(eventName: "PreToolUse",
                                              data: Data(json.utf8), timestamp: ts)
        XCTAssertEqual(e.event, .preToolUse)
        XCTAssertEqual(e.sessionId, "s1")
        XCTAssertEqual(e.cwd, "/p/muster")
        XCTAssertEqual(e.transcriptPath, "/t/s1.jsonl")
        XCTAssertEqual(e.toolName, "Bash")
        XCTAssertEqual(e.timestamp, ts)
    }

    func testNotificationWithMessage() throws {
        let json = #"{"session_id":"s2","message":"Claude needs your permission to use Bash"}"#
        let e = try HookEvent.fromClaudeStdin(eventName: "Notification",
                                              data: Data(json.utf8), timestamp: ts)
        XCTAssertEqual(e.event, .notification)
        XCTAssertEqual(e.message, "Claude needs your permission to use Bash")
        XCTAssertNil(e.toolName)
    }

    func testMissingFieldsTolerated() throws {
        let e = try HookEvent.fromClaudeStdin(eventName: "Stop",
                                              data: Data("{}".utf8), timestamp: ts)
        XCTAssertEqual(e.event, .stop)
        XCTAssertEqual(e.sessionId, "")
    }

    func testUnknownEventThrows() {
        XCTAssertThrowsError(try HookEvent.fromClaudeStdin(
            eventName: "Bogus", data: Data("{}".utf8), timestamp: ts)) { err in
            XCTAssertEqual(err as? MusterError, .unknownEvent("Bogus"))
        }
    }
}
