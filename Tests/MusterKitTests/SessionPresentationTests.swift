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

    func enriched(status: SessionStatus, branch: String?, model: String?,
                  prompt: String?, title: String?) -> Session {
        Session(id: "x", projectName: "p", title: title, status: status,
                lastEventAt: t0, gitBranch: branch, model: model, lastPrompt: prompt)
    }

    func testMetaLineJoinsBranchAndModel() {
        XCTAssertEqual(metaLine(for: enriched(status: .idle, branch: "main", model: "opus",
                                              prompt: nil, title: nil)), "main · opus")
        XCTAssertEqual(metaLine(for: enriched(status: .idle, branch: "main", model: nil,
                                              prompt: nil, title: nil)), "main")
        XCTAssertNil(metaLine(for: enriched(status: .idle, branch: nil, model: nil,
                                            prompt: nil, title: nil)))
    }

    func testSubtitlePrecedence() {
        // working with activity → activity
        XCTAssertEqual(subtitle(for: enriched(status: .working(activity: "Running: Bash"),
                                              branch: nil, model: nil, prompt: "p", title: "t")),
                       "Running: Bash")
        // not working → lastPrompt beats title
        XCTAssertEqual(subtitle(for: enriched(status: .idle, branch: nil, model: nil,
                                              prompt: "the prompt", title: "the title")),
                       "the prompt")
        // no prompt → title
        XCTAssertEqual(subtitle(for: enriched(status: .idle, branch: nil, model: nil,
                                              prompt: nil, title: "the title")),
                       "the title")
        // nothing → status label
        XCTAssertEqual(subtitle(for: enriched(status: .needsYou(reason: .yourTurn),
                                              branch: nil, model: nil, prompt: nil, title: nil)),
                       "Your turn")
    }

    func testRevealTarget() {
        let withCwd = Session(id: "x", projectName: "p", cwd: "/Users/jlk/Projects/muster",
                              status: .idle, lastEventAt: t0)
        XCTAssertEqual(revealTarget(for: withCwd)?.path, "/Users/jlk/Projects/muster")
        let noCwd = Session(id: "y", projectName: "p", cwd: nil, status: .idle, lastEventAt: t0)
        XCTAssertNil(revealTarget(for: noCwd))
        let emptyCwd = Session(id: "z", projectName: "p", cwd: "", status: .idle, lastEventAt: t0)
        XCTAssertNil(revealTarget(for: emptyCwd))
    }

    func testPrimaryLabelPrefersNameThenProjectName() {
        let base = Session(id: "s", projectName: "muster", status: .idle,
                           lastEventAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(primaryLabel(for: base), "muster")

        var named = base; named.name = "muster-56"
        XCTAssertEqual(primaryLabel(for: named), "muster-56")

        var empty = base; empty.name = ""
        XCTAssertEqual(primaryLabel(for: empty), "muster")   // empty name falls back
    }
}
