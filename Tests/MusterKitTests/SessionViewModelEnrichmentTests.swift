import XCTest
import MusterCore
@testable import MusterKit

private struct FakeEnricher: TranscriptEnriching {
    let summaries: [String: TranscriptSummary]  // keyed by path
    func enrich(path: String) -> TranscriptSummary? { summaries[path] }
}

final class SessionViewModelEnrichmentTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func makeVM(enricher: TranscriptEnriching = FakeEnricher(summaries: [:]),
                mtime: @escaping (String) -> Date? = { _ in nil }) -> SessionViewModel {
        SessionViewModel(socketPath: NSTemporaryDirectory() + "vm-\(UUID().uuidString).sock",
                         projectsDir: NSTemporaryDirectory() + "no-such-projects",
                         idleAfter: 300, dropAfter: 1800,
                         enricher: enricher, fileMtime: mtime)
    }

    func working(_ vm: SessionViewModel) {
        vm.ingest(HookEvent(event: .preToolUse, sessionId: "s1", cwd: "/p/muster",
                            transcriptPath: "/t/s1.jsonl", toolName: "Bash",
                            message: nil, timestamp: t0))
    }

    func testApplyEnrichmentMergesFieldsAndPreservesStatus() {
        let vm = makeVM()
        working(vm)
        let summary = TranscriptSummary(title: "T", cwd: "/p/muster", gitBranch: "main",
                                        model: "claude-opus-4-8", lastPrompt: "hi")
        vm.applyEnrichmentResults([.init(id: "s1", mtime: t0, summary: summary)])
        let s = vm.sessions.first { $0.id == "s1" }
        XCTAssertEqual(s?.gitBranch, "main")
        XCTAssertEqual(s?.model, "opus")          // shortened at merge
        XCTAssertEqual(s?.lastPrompt, "hi")
        XCTAssertEqual(s?.title, "T")
        XCTAssertEqual(s?.status, .working(activity: "Running: Bash"))
        XCTAssertEqual(s?.currentTool, "Bash")
    }

    func testApplyEnrichmentUnknownIdIsNoOp() {
        let vm = makeVM()
        working(vm)
        vm.applyEnrichmentResults([.init(id: "ghost", mtime: t0,
                                         summary: TranscriptSummary(gitBranch: "x"))])
        XCTAssertNil(vm.sessions.first { $0.id == "s1" }?.gitBranch)
    }

    func testNeedingEnrichmentSkipsUnchangedIncludesChangedAndNew() {
        // Seeded session "old": lastEnriched recorded from its scanned mtime.
        let scannedMtime = t0.addingTimeInterval(-100)
        var currentMtimes: [String: Date] = ["/t/old.jsonl": scannedMtime] // unchanged
        let vm = makeVM(mtime: { currentMtimes[$0] })
        vm.seed([ScannedSession(id: "old", path: "/t/old.jsonl", modifiedAt: scannedMtime,
                                title: "Old", cwd: "/p/muster")], now: t0)
        XCTAssertTrue(vm.sessionsNeedingEnrichment().isEmpty)   // unchanged → skip

        currentMtimes["/t/old.jsonl"] = t0                       // file changed
        XCTAssertEqual(vm.sessionsNeedingEnrichment().map(\.id), ["old"])

        // Hook-created session (never enriched) with a readable mtime → needs enrichment.
        currentMtimes["/t/s1.jsonl"] = t0
        working(vm)
        XCTAssertTrue(Set(vm.sessionsNeedingEnrichment().map(\.id)).isSuperset(of: ["s1"]))
    }

    func testSeedShortensModelName() {
        let vm = makeVM()
        vm.seed([ScannedSession(id: "old", path: "/t/old.jsonl", modifiedAt: t0,
                                title: "Old", cwd: "/p/muster",
                                gitBranch: "main", model: "claude-haiku-4-5-20251001")], now: t0)
        let s = vm.sessions.first { $0.id == "old" }
        XCTAssertEqual(s?.model, "haiku")
        XCTAssertEqual(s?.gitBranch, "main")
    }
}
