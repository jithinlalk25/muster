import XCTest
@testable import MusterCore

final class SessionTests: XCTestCase {
    func testProjectNameFromCwd() {
        XCTAssertEqual(projectName(fromCwd: "/Users/jlk/Projects/muster"), "muster")
        XCTAssertEqual(projectName(fromCwd: "/Users/jlk/Projects/muster/"), "muster")
        XCTAssertEqual(projectName(fromCwd: nil), "unknown")
        XCTAssertEqual(projectName(fromCwd: ""), "unknown")
    }

    func testStatusEquatable() {
        XCTAssertEqual(SessionStatus.needsYou(reason: .permission),
                       SessionStatus.needsYou(reason: .permission))
        XCTAssertNotEqual(SessionStatus.needsYou(reason: .permission),
                          SessionStatus.needsYou(reason: .yourTurn))
        XCTAssertEqual(SessionStatus.working(activity: "Running: Bash"),
                       SessionStatus.working(activity: "Running: Bash"))
    }
}
