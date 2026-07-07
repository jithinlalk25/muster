import XCTest
@testable import MusterCore

final class HookEventTests: XCTestCase {
    func testWireRoundTrip() throws {
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let e = HookEvent(event: .preToolUse, sessionId: "abc",
                          cwd: "/Users/jlk/Projects/muster",
                          transcriptPath: "/x/abc.jsonl",
                          toolName: "Bash", message: nil, timestamp: ts)
        let line = try e.wireLine()
        XCTAssertEqual(line.last, 0x0A) // newline-terminated
        let decoded = try HookEvent.decode(wire: line.dropLast()) // strip \n
        XCTAssertEqual(decoded, e)
    }

    func testEventKindRawValues() {
        XCTAssertEqual(EventKind.stop.rawValue, "Stop")
        XCTAssertEqual(EventKind(rawValue: "SubagentStop"), .subagentStop)
    }
}
