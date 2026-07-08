import XCTest
import MusterCore
@testable import MusterKit

final class SessionPresentationTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func session(_ id: String, _ status: SessionStatus, at: TimeInterval) -> Session {
        Session(id: id, projectName: "p", status: status, lastEventAt: t0.addingTimeInterval(at))
    }

    func testDotMapping() {
        XCTAssertEqual(dot(for: .working(activity: nil)), .working)
        XCTAssertEqual(dot(for: .needsYou(reason: .permission)), .needsYou)
        XCTAssertEqual(dot(for: .idle), .idle)
    }

    func testStatusLabels() {
        XCTAssertEqual(statusLabel(for: .working(activity: "Running: Bash")), "Working")
        XCTAssertEqual(statusLabel(for: .needsYou(reason: .yourTurn)), "Your turn")
        XCTAssertEqual(statusLabel(for: .needsYou(reason: .permission)), "Permission")
        XCTAssertEqual(statusLabel(for: .idle), "Idle")
    }

    func testSortNeedsYouFirstThenWorkingThenIdle() {
        let input = [
            session("idle", .idle, at: 100),
            session("work", .working(activity: nil), at: 100),
            session("need", .needsYou(reason: .yourTurn), at: 100),
        ]
        XCTAssertEqual(sortedForDisplay(input).map(\.id), ["need", "work", "idle"])
    }

    func testSortWithinGroupNewestFirst() {
        let input = [
            session("old", .needsYou(reason: .yourTurn), at: 10),
            session("new", .needsYou(reason: .permission), at: 90),
        ]
        XCTAssertEqual(sortedForDisplay(input).map(\.id), ["new", "old"])
    }

    func testBadgeCountsOnlyNeedsYou() {
        let input = [
            session("a", .needsYou(reason: .yourTurn), at: 1),
            session("b", .needsYou(reason: .permission), at: 2),
            session("c", .working(activity: nil), at: 3),
            session("d", .idle, at: 4),
        ]
        let badge = badgeState(for: input)
        XCTAssertEqual(badge.needsYouCount, 2)
        XCTAssertTrue(badge.isAlert)
        XCTAssertFalse(badgeState(for: []).isAlert)
    }

    func testShortModelName() {
        XCTAssertEqual(shortModelName("claude-opus-4-8"), "opus")
        XCTAssertEqual(shortModelName("claude-sonnet-5"), "sonnet")
        XCTAssertEqual(shortModelName("claude-haiku-4-5-20251001"), "haiku")
        XCTAssertEqual(shortModelName("claude-fable-5"), "fable")
        XCTAssertNil(shortModelName("<synthetic>"))
        XCTAssertNil(shortModelName(""))
        XCTAssertNil(shortModelName(nil))
        XCTAssertEqual(shortModelName("gpt-5"), "gpt-5") // unknown passes through
    }
}
