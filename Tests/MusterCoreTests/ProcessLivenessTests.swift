import XCTest
import Foundation
@testable import MusterCore

final class ProcessLivenessTests: XCTestCase {
    func testCurrentProcessIsAlive() {
        XCTAssertTrue(DefaultProcessLiveness().isAlive(getpid()))
    }

    func testImplausiblePidIsDead() {
        // macOS default max pid is 99998; a far-larger pid reliably yields ESRCH.
        XCTAssertFalse(DefaultProcessLiveness().isAlive(99_000_000))
    }

    func testNonPositivePidIsDead() {
        XCTAssertFalse(DefaultProcessLiveness().isAlive(0))
        XCTAssertFalse(DefaultProcessLiveness().isAlive(-1))
    }
}
