import XCTest
import MusterCore
@testable import MusterKit

private struct FakePidReader: PidSessionReading {
    let sessions: [PidSession]
    func read() -> [PidSession] { sessions }
}

/// Liveness keyed on pid: only the pids in `alive` are considered running.
private struct FakeLiveness: ProcessLiveness {
    let alive: Set<Int32>
    func isAlive(_ pid: Int32) -> Bool { alive.contains(pid) }
}

final class SessionViewModelPidTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func makeVM() -> SessionViewModel {
        SessionViewModel(socketPath: NSTemporaryDirectory() + "vm-\(UUID().uuidString).sock",
                         projectsDir: "/proj", sessionsDir: "/unused",
                         idleAfter: 300, dropAfter: 1800)
    }

    /// Each fixture carries a distinct pid so `FakeLiveness` can select by pid.
    func pid(_ id: String, _ status: PidStatus, pidNum: Int32 = 42, name: String = "muster-56",
             cwd: String = "/p/muster") -> PidSession {
        PidSession(pid: pidNum, sessionId: id, cwd: cwd, name: name, status: status, statusUpdatedAt: t0)
    }

    func testApplySeedsRowWithNameAndPublishes() {
        let vm = makeVM()
        vm.applyAlivePidSessions([pid("a", .busy)], now: t0)
        let s = vm.sessions.first { $0.id == "a" }
        XCTAssertEqual(s?.name, "muster-56")
        XCTAssertEqual(s?.status, .working(activity: nil))
    }

    func testApplyPrunesDeadPidBackedRow() {
        let vm = makeVM()
        vm.applyAlivePidSessions([pid("a", .idle)], now: t0)
        vm.applyAlivePidSessions([], now: t0)               // "a" no longer alive
        XCTAssertNil(vm.sessions.first { $0.id == "a" })
    }

    func testSeededRowGetsDerivedTranscriptPath() {
        let vm = makeVM()
        vm.applyAlivePidSessions([pid("a", .idle, cwd: "/Users/jlk/Projects/muster")], now: t0)
        let s = vm.sessions.first { $0.id == "a" }
        XCTAssertEqual(s?.transcriptPath, "/proj/-Users-jlk-Projects-muster/a.jsonl")
    }

    func testClaudeTranscriptPathSlug() {
        XCTAssertEqual(
            claudeTranscriptPath(projectsDir: "/proj", cwd: "/Users/jlk/Projects/muster", sessionId: "x"),
            "/proj/-Users-jlk-Projects-muster/x.jsonl")
        XCTAssertNil(claudeTranscriptPath(projectsDir: "/proj", cwd: nil, sessionId: "x"))
        XCTAssertNil(claudeTranscriptPath(projectsDir: "/proj", cwd: "", sessionId: "x"))
    }

    func testPollUsesLivenessFilter() {
        let reader = FakePidReader(sessions: [pid("alive", .idle, pidNum: 10),
                                              pid("dead", .idle, pidNum: 20)])
        let vm = SessionViewModel(socketPath: NSTemporaryDirectory() + "vm-\(UUID().uuidString).sock",
                                  projectsDir: "/proj", sessionsDir: "/unused",
                                  idleAfter: 300, dropAfter: 1800,
                                  pidReader: reader, liveness: FakeLiveness(alive: [10]))
        vm.pollPidSessions(now: t0)
        // pollPidSessions hops to enrichQueue then back to main; drain both so the apply lands.
        let exp = expectation(description: "async apply")
        vm.enrichQueueForTests.async { DispatchQueue.main.async { exp.fulfill() } }
        wait(for: [exp], timeout: 2)
        XCTAssertNotNil(vm.sessions.first { $0.id == "alive" })
        XCTAssertNil(vm.sessions.first { $0.id == "dead" })
    }
}
