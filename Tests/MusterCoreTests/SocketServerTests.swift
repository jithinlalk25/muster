import XCTest
@testable import MusterCore

final class SocketServerTests: XCTestCase {
    func testReceivesEventFromClient() throws {
        let path = NSTemporaryDirectory() + "muster-test-\(UUID().uuidString).sock"
        let received = expectation(description: "event received")
        var got: HookEvent?

        let server = SocketServer(path: path, queue: .main) { ev in
            got = ev
            received.fulfill()
        }
        try server.start()
        defer { server.stop() }

        // Raw client: connect and write one wire line.
        let ev = HookEvent(event: .stop, sessionId: "s1", cwd: "/p/muster",
                           transcriptPath: nil, toolName: nil, message: nil,
                           timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        let fd = try XCTUnwrap(UnixSocket.connect(path: path))
        let line = try ev.wireLine()
        line.withUnsafeBytes { _ = write(fd, $0.baseAddress, line.count) }
        close(fd)

        wait(for: [received], timeout: 2.0)
        XCTAssertEqual(got, ev)
    }
}
