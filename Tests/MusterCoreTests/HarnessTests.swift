import XCTest
@testable import MusterCore

final class HarnessTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertEqual(Muster.version, "0.2.0")
    }
}
