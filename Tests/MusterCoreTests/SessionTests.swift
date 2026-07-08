import XCTest
@testable import MusterCore

final class SessionTests: XCTestCase {
    func testProjectNameFromCwd() {
        XCTAssertEqual(projectName(fromCwd: "/Users/jlk/Projects/muster"), "muster")
        XCTAssertEqual(projectName(fromCwd: "/Users/jlk/Projects/muster/"), "muster")
        XCTAssertEqual(projectName(fromCwd: nil), "unknown")
        XCTAssertEqual(projectName(fromCwd: ""), "unknown")
        XCTAssertEqual(projectName(fromCwd: "/"), "unknown")
        XCTAssertEqual(projectName(fromCwd: "//"), "unknown")
    }

    func testStatusEquatable() {
        XCTAssertEqual(SessionStatus.needsYou(reason: .permission),
                       SessionStatus.needsYou(reason: .permission))
        XCTAssertNotEqual(SessionStatus.needsYou(reason: .permission),
                          SessionStatus.needsYou(reason: .yourTurn))
        XCTAssertEqual(SessionStatus.working(activity: "Running: Bash"),
                       SessionStatus.working(activity: "Running: Bash"))
    }

    func testNameAndPidDefaultNilAndRoundTrip() {
        let bare = Session(id: "s1", projectName: "muster", status: .idle,
                           lastEventAt: Date(timeIntervalSince1970: 0))
        XCTAssertNil(bare.name)
        XCTAssertNil(bare.pid)

        let full = Session(id: "s2", projectName: "muster", status: .idle,
                           lastEventAt: Date(timeIntervalSince1970: 0),
                           name: "muster-56", pid: 63657)
        XCTAssertEqual(full.name, "muster-56")
        XCTAssertEqual(full.pid, 63657)
    }
}
