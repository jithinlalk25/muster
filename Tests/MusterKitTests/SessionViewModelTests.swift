import XCTest
import MusterCore
@testable import MusterKit

final class SessionViewModelTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func makeVM() -> SessionViewModel {
        SessionViewModel(socketPath: NSTemporaryDirectory() + "vm-\(UUID().uuidString).sock",
                         projectsDir: NSTemporaryDirectory() + "no-such-projects",
                         idleAfter: 300, dropAfter: 1800)
    }

    func ev(_ k: EventKind, tool: String? = nil, at: Date) -> HookEvent {
        HookEvent(event: k, sessionId: "s1", cwd: "/p/muster",
                  transcriptPath: "/t/s1.jsonl", toolName: tool, message: nil, timestamp: at)
    }

    func testIngestUpdatesSessionsAndBadge() {
        let vm = makeVM()
        vm.ingest(ev(.stop, at: t0))
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions.first?.status, .needsYou(reason: .yourTurn))
        XCTAssertEqual(vm.badge.needsYouCount, 1)
    }

    func testSeedInsertsIdleSessions() {
        let vm = makeVM()
        let scanned = ScannedSession(id: "old", path: "/t/old.jsonl",
                                     modifiedAt: t0.addingTimeInterval(-120),
                                     title: "Old", cwd: "/Users/jlk/Projects/muster")
        vm.seed([scanned], now: t0)
        XCTAssertEqual(vm.sessions.map(\.id), ["old"])
        XCTAssertEqual(vm.sessions.first?.status, .idle)
        XCTAssertEqual(vm.sessions.first?.projectName, "muster")
        XCTAssertEqual(vm.sessions.first?.title, "Old")
    }

    func testAgeNowDropsStaleIdle() {
        let vm = makeVM()
        vm.ingest(ev(.sessionStart, at: t0)) // idle
        vm.ageNow(t0.addingTimeInterval(300 + 1800 + 1))
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertFalse(vm.badge.isAlert)
    }

    func testDisplayOrderNeedsYouFirst() {
        let vm = makeVM()
        vm.ingest(HookEvent(event: .userPromptSubmit, sessionId: "work", cwd: "/p/w",
                            transcriptPath: nil, toolName: nil, message: nil, timestamp: t0))
        vm.ingest(HookEvent(event: .stop, sessionId: "need", cwd: "/p/n",
                            transcriptPath: nil, toolName: nil, message: nil, timestamp: t0))
        XCTAssertEqual(vm.sessions.first?.id, "need")
    }
}
