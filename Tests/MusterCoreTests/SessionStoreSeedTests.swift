import XCTest
@testable import MusterCore

final class SessionStoreSeedTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func session(_ id: String, status: SessionStatus, at: Date) -> Session {
        Session(id: id, projectName: "muster", cwd: "/p/muster",
                transcriptPath: "/t/\(id).jsonl", title: "T", status: status, lastEventAt: at)
    }

    func testSeedInsertsWhenAbsent() {
        let store = SessionStore()
        store.seed(session("s1", status: .idle, at: t0))
        XCTAssertEqual(store.sessions["s1"]?.status, .idle)
        XCTAssertEqual(store.sessions["s1"]?.title, "T")
    }

    func testSeedDoesNotOverwriteLiveSession() {
        let store = SessionStore()
        _ = store.apply(HookEvent(event: .stop, sessionId: "s1", cwd: "/p/muster",
                                  transcriptPath: nil, toolName: nil, message: nil, timestamp: t0))
        store.seed(session("s1", status: .idle, at: t0.addingTimeInterval(-999)))
        XCTAssertEqual(store.sessions["s1"]?.status, .needsYou(reason: .yourTurn)) // unchanged
    }
}
