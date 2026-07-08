import XCTest
@testable import MusterCore

final class SessionStoreEnrichTests: XCTestCase {
    let ts = Date(timeIntervalSince1970: 1_700_000_000)

    func working(_ store: SessionStore) {
        _ = store.apply(HookEvent(event: .preToolUse, sessionId: "s1", cwd: "/p/muster",
                                  transcriptPath: "/t/s1.jsonl", toolName: "Bash",
                                  message: nil, timestamp: ts))
    }

    func testEnrichSetsFieldsAndPreservesHookState() {
        let store = SessionStore()
        working(store)
        store.enrich("s1", gitBranch: "main", model: "opus", lastPrompt: "hi", title: "T")
        let s = store.sessions["s1"]
        XCTAssertEqual(s?.gitBranch, "main")
        XCTAssertEqual(s?.model, "opus")
        XCTAssertEqual(s?.lastPrompt, "hi")
        XCTAssertEqual(s?.title, "T")
        // hook-owned state untouched
        XCTAssertEqual(s?.status, .working(activity: "Running: Bash"))
        XCTAssertEqual(s?.currentTool, "Bash")
        XCTAssertEqual(s?.lastEventAt, ts)
    }

    func testEnrichNilDoesNotClobberExisting() {
        let store = SessionStore()
        working(store)
        store.enrich("s1", gitBranch: "main", model: "opus", lastPrompt: nil, title: nil)
        store.enrich("s1", gitBranch: nil, model: nil, lastPrompt: "later", title: nil)
        XCTAssertEqual(store.sessions["s1"]?.gitBranch, "main")   // preserved
        XCTAssertEqual(store.sessions["s1"]?.model, "opus")       // preserved
        XCTAssertEqual(store.sessions["s1"]?.lastPrompt, "later") // updated
    }

    func testEnrichUnknownIdIsNoOp() {
        let store = SessionStore()
        store.enrich("ghost", gitBranch: "main", model: "opus", lastPrompt: "x", title: "y")
        XCTAssertNil(store.sessions["ghost"])
    }
}
