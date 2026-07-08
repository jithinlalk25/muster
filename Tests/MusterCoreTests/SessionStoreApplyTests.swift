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

    func testNotificationPermissionRequestSetsPermission() {
        let store = SessionStore()
        _ = store.apply(ev(.notification, msg: "Claude needs your permission to use Bash"))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .permission))
    }

    func testNotificationIdlePromptSetsYourTurn() {
        // The ~60s idle notification is NOT a permission request; it means Claude is
        // waiting on the user, which is the same as a your-turn state.
        let store = SessionStore()
        _ = store.apply(ev(.notification, msg: "Claude is waiting for your input"))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
    }

    func testNotificationWithoutMessageDefaultsToYourTurn() {
        let store = SessionStore()
        _ = store.apply(ev(.notification, msg: nil))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
    }

    func testNotificationDoesNotDowngradeIsHandledByMessage() {
        // Regression for the bug where a your-turn session got rewritten to permission:
        // Stop → your turn, then the idle notification (~60s later) must stay your turn.
        let store = SessionStore()
        _ = store.apply(ev(.stop))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
        _ = store.apply(ev(.notification, msg: "Claude is waiting for your input"))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
    }

    func testPostToolUseClearsCurrentTool() {
        // Once a tool finishes, no tool is in flight — currentTool must not linger.
        let store = SessionStore()
        _ = store.apply(ev(.preToolUse, tool: "Bash"))
        XCTAssertEqual(store.sessions["s1"]?.currentTool, "Bash")
        _ = store.apply(ev(.postToolUse, tool: "Bash"))
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: "Ran: Bash"))
        XCTAssertNil(store.sessions["s1"]?.currentTool)
    }

    func testSubagentStopReturnsToWorkingWithoutStaleTool() {
        // After a subagent returns, the main agent is thinking again. Reusing the last
        // tool name ("Running: Task") would show a tool that has already finished.
        let store = SessionStore()
        _ = store.apply(ev(.preToolUse, tool: "Task"))
        _ = store.apply(ev(.subagentStop))
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: nil))
    }

    func testSessionEndRemoves() {
        let store = SessionStore()
        _ = store.apply(ev(.userPromptSubmit))
        let result = store.apply(ev(.sessionEnd))
        XCTAssertNil(result)
        XCTAssertNil(store.sessions["s1"])
    }

    func emptyIdEvent(_ k: EventKind) -> HookEvent {
        HookEvent(event: k, sessionId: "", cwd: "/p/muster", transcriptPath: nil,
                  toolName: nil, message: nil, timestamp: ts)
    }

    func testEmptySessionIdIsRejected() {
        let store = SessionStore()
        let result = store.apply(emptyIdEvent(.userPromptSubmit))
        XCTAssertNil(result)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testEmptySessionIdEndDoesNotWipeExistingSessions() {
        let store = SessionStore()
        _ = store.apply(ev(.userPromptSubmit)) // real session "s1"
        let result = store.apply(emptyIdEvent(.sessionEnd))
        XCTAssertNil(result)
        XCTAssertNotNil(store.sessions["s1"])
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
