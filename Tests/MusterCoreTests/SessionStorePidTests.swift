import XCTest
@testable import MusterCore

final class SessionStorePidTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let idle: TimeInterval = 300
    let drop: TimeInterval = 1800

    func pid(_ id: String, _ status: PidStatus, pid: Int32 = 1, name: String = "n",
             cwd: String = "/p/muster") -> PidSession {
        PidSession(pid: pid, sessionId: id, cwd: cwd, name: name,
                   status: status, statusUpdatedAt: t0)
    }
    func hook(_ store: SessionStore, _ k: EventKind, id: String = "s1", tool: String? = nil) {
        store.apply(HookEvent(event: k, sessionId: id, cwd: "/p/muster",
                              transcriptPath: nil, toolName: tool, message: nil, timestamp: t0))
    }
    func noPath(_ p: PidSession) -> String? { nil }

    func testSeedsUnseenBusyAndIdle() {
        let store = SessionStore()
        store.applyPidSessions([pid("a", .busy), pid("b", .idle)], now: t0, transcriptPath: noPath)
        XCTAssertEqual(store.sessions["a"]?.status, .working(activity: nil))
        XCTAssertEqual(store.sessions["b"]?.status, .idle)
        XCTAssertEqual(store.sessions["a"]?.name, "n")
        XCTAssertEqual(store.sessions["a"]?.pid, 1)
        XCTAssertEqual(store.sessions["b"]?.lastEventAt, t0)   // from statusUpdatedAt
    }

    func testSeedUsesTranscriptPathResolver() {
        let store = SessionStore()
        store.applyPidSessions([pid("a", .idle)], now: t0) { "/t/\($0.sessionId).jsonl" }
        XCTAssertEqual(store.sessions["a"]?.transcriptPath, "/t/a.jsonl")
    }

    func testPromotesIdleRowToWorkingWhenBusy() {
        let store = SessionStore()
        hook(store, .sessionStart)                 // idle, pid == nil
        store.applyPidSessions([pid("s1", .busy)], now: t0, transcriptPath: noPath)
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: nil))
        XCTAssertEqual(store.sessions["s1"]?.pid, 1)
    }

    func testNeverDemotesWorkingWhenIdle() {
        let store = SessionStore()
        hook(store, .preToolUse, tool: "Bash")     // working
        store.applyPidSessions([pid("s1", .idle)], now: t0, transcriptPath: noPath)
        XCTAssertEqual(store.sessions["s1"]?.status, .working(activity: "Running: Bash"))
    }

    func testPreservesNeedsYouUnderBusyAndIdle() {
        for st in [PidStatus.busy, .idle] {
            let store = SessionStore()
            hook(store, .stop)                     // needsYou(.yourTurn)
            store.applyPidSessions([pid("s1", st)], now: t0, transcriptPath: noPath)
            XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn))
            XCTAssertEqual(store.sessions["s1"]?.name, "n")   // name still refreshed
        }
    }

    func testPrunesPidBackedRowWhoseProcessIsGone() {
        let store = SessionStore()
        store.applyPidSessions([pid("a", .idle)], now: t0, transcriptPath: noPath)  // seeds a, pid set
        let removed = store.applyPidSessions([], now: t0, transcriptPath: noPath)    // a no longer alive
        XCTAssertEqual(removed, ["a"])
        XCTAssertNil(store.sessions["a"])
    }

    func testDoesNotPruneLegacyRowWithNoPid() {
        let store = SessionStore()
        hook(store, .stop, id: "legacy")           // pid == nil
        let removed = store.applyPidSessions([], now: t0, transcriptPath: noPath)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertNotNil(store.sessions["legacy"])
    }

    func testAgeDoesNotDropPidBackedIdleButDropsLegacyIdle() {
        let store = SessionStore()
        store.applyPidSessions([pid("live", .idle)], now: t0, transcriptPath: noPath) // pid-backed idle
        hook(store, .sessionStart, id: "legacy")                                      // legacy idle
        let removed = store.age(now: t0.addingTimeInterval(idle + drop + 1),
                                idleAfter: idle, dropAfter: drop)
        XCTAssertEqual(removed, ["legacy"])
        XCTAssertNotNil(store.sessions["live"])
        XCTAssertNil(store.sessions["legacy"])
    }
}
