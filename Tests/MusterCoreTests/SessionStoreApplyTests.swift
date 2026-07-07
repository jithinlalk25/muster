import XCTest
@testable import MusterCore

final class SessionStoreApplyTests: XCTestCase {
    let ts = Date(timeIntervalSince1970: 1_700_000_000)
    func ev(_ k: EventKind, tool: String? = nil, msg: String? = nil,
            cwd: String? = "/p/muster", at: Date? = nil) -> HookEvent {
        HookEvent(event: k, sessionId: "s1", cwd: cwd, transcriptPath: "/t/s1.jsonl",
                  toolName: tool, message: msg, timestamp: at ?? ts)
    }

    func testStartThenPromptThenTool() {
        let store = SessionStore()
        _ = store.apply(ev(.sessionStart))
        XCTAssertEqual(store.sessions["s1"]?.status, .idle)
        XCTAssertEqual(store.sessions["s1"]?.projectName, "muster")

        _ = store.apply(ev(.userPromptSubmit))
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: nil))

        _ = store.apply(ev(.preToolUse, tool: "Bash"))
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: "Running: Bash"))
        XCTAssertEqual(store.sessions["s1"]?.currentTool, "Bash")
    }

    func testStopSetsNeedsYou() {
        let store = SessionStore()
        _ = store.apply(ev(.preToolUse, tool: "Bash"))
        _ = store.apply(ev(.stop))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
        XCTAssertNil(store.sessions["s1"]?.currentTool)
    }

    func testNotificationSetsPermission() {
        let store = SessionStore()
        _ = store.apply(ev(.notification, msg: "needs permission"))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .permission))
    }

    func testSubagentStopStaysWorking() {
        let store = SessionStore()
        _ = store.apply(ev(.preToolUse, tool: "Task"))
        _ = store.apply(ev(.subagentStop))
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: "Running: Task"))
    }

    func testSessionEndRemoves() {
        let store = SessionStore()
        _ = store.apply(ev(.userPromptSubmit))
        let result = store.apply(ev(.sessionEnd))
        XCTAssertNil(result)
        XCTAssertNil(store.sessions["s1"])
    }

    func testLastEventAtRefreshes() {
        let store = SessionStore()
        _ = store.apply(ev(.userPromptSubmit, at: ts))
        let later = ts.addingTimeInterval(60)
        _ = store.apply(ev(.postToolUse, tool: "Read", at: later))
        XCTAssertEqual(store.sessions["s1"]?.lastEventAt, later)
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: "Ran: Read"))
    }
}
