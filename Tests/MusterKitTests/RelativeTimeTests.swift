import XCTest
@testable import MusterKit

final class RelativeTimeTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    func rel(_ secondsAgo: TimeInterval) -> String {
        relativeTime(from: t0, to: t0.addingTimeInterval(secondsAgo))
    }

    func testJustNowUnder45s() {
        XCTAssertEqual(rel(0), "just now")
        XCTAssertEqual(rel(44), "just now")
    }

    func testMinutes() {
        XCTAssertEqual(rel(60), "1m")
        XCTAssertEqual(rel(300), "5m")
        XCTAssertEqual(rel(3540), "59m")
    }

    func testHours() {
        XCTAssertEqual(rel(3600), "1h")
        XCTAssertEqual(rel(7200), "2h")
    }

    func testDays() {
        XCTAssertEqual(rel(86_400), "1d")
        XCTAssertEqual(rel(259_200), "3d")
    }

    func testFutureClampsToJustNow() {
        XCTAssertEqual(rel(-500), "just now")
    }
}
