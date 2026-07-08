import XCTest
@testable import MusterCore

final class HomeDirectoryTests: XCTestCase {
    // Regression: NSHomeDirectory() ignores $HOME on macOS, so the app wrote to the
    // real ~/.claude even when launched with HOME overridden for sandboxed testing.
    func testPrefersHOMEEnvironmentVariable() {
        let home = HomeDirectory.resolved(environment: ["HOME": "/tmp/muster-e2e-home"])
        XCTAssertEqual(home, "/tmp/muster-e2e-home")
    }

    func testFallsBackToNSHomeDirectoryWhenHOMEAbsent() {
        let home = HomeDirectory.resolved(environment: [:])
        XCTAssertEqual(home, NSHomeDirectory())
    }

    func testFallsBackToNSHomeDirectoryWhenHOMEEmpty() {
        let home = HomeDirectory.resolved(environment: ["HOME": ""])
        XCTAssertEqual(home, NSHomeDirectory())
    }
}
