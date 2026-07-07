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

    func testClientSourceReclaimedOnDisconnect() throws {
        let path = NSTemporaryDirectory() + "muster-cleanup-\(UUID().uuidString).sock"
        let got = expectation(description: "event received")
        let server = SocketServer(path: path, queue: .main) { _ in got.fulfill() }
        try server.start()
        defer { server.stop() }

        let fd = try XCTUnwrap(UnixSocket.connect(path: path))
        let ev = HookEvent(event: .stop, sessionId: "s1",
                           timestamp: Date(timeIntervalSince1970: 1))
        let line = try ev.wireLine()
        line.withUnsafeBytes { _ = write(fd, $0.baseAddress, line.count) }
        wait(for: [got], timeout: 2.0)
        XCTAssertEqual(server.clientCount, 1)

        close(fd) // client disconnects -> server should reclaim its source
        let reclaimed = expectation(description: "client source reclaimed")
        func poll() {
            if server.clientCount == 0 { reclaimed.fulfill() }
            else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: poll) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: poll)
        wait(for: [reclaimed], timeout: 2.0)
        XCTAssertEqual(server.clientCount, 0)
    }
}
