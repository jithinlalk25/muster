import XCTest
@testable import MusterKit

final class MusterKitHarnessTests: XCTestCase {
    func testCoreVersionWired() {
        XCTAssertEqual(MusterKit.coreVersion, "0.1.0")
    }
}
