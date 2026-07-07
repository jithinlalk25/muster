import XCTest
@testable import MusterCore

final class SessionStoreAgingTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let idle: TimeInterval = 300    // 5 min
    let drop: TimeInterval = 1800   // 30 min

    func seed(_ store: SessionStore, _ k: EventKind, tool: String? = nil) {
        store.apply(HookEvent(event: k, sessionId: "s1", cwd: "/p/muster",
                              transcriptPath: nil, toolName: tool, message: nil, timestamp: t0))
    }

    func testWorkingBecomesIdleAfterN() {
        let store = SessionStore()
        seed(store, .preToolUse, tool: "Bash")
        let removed = store.age(now: t0.addingTimeInterval(301), idleAfter: idle, dropAfter: drop)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertEqual(store.sessions["s1"]?.status, .idle)
    }

    func testWorkingStaysBeforeN() {
        let store = SessionStore()
        seed(store, .preToolUse, tool: "Bash")
        _ = store.age(now: t0.addingTimeInterval(299), idleAfter: idle, dropAfter: drop)
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: "Running: Bash"))
    }

    func testIdleDropsAfterNPlusM() {
        let store = SessionStore()
        seed(store, .sessionStart) // starts idle
        let removed = store.age(now: t0.addingTimeInterval(300 + 1800 + 1),
                                idleAfter: idle, dropAfter: drop)
        XCTAssertEqual(removed, ["s1"])
        XCTAssertNil(store.sessions["s1"])
    }

    func testNeedsYouNeverAges() {
        let store = SessionStore()
        seed(store, .stop) // needsYou(.yourTurn)
        let removed = store.age(now: t0.addingTimeInterval(100_000), idleAfter: idle, dropAfter: drop)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
    }
}
