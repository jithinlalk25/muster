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

    func testConnectedSocketSurvivesWriteToClosedPeer() throws {
        // Proves UnixSocket.connect sets SO_NOSIGPIPE: without it, writing to a
        // peer that has closed delivers SIGPIPE and kills this test process.
        let path = NSTemporaryDirectory() + "muster-sigpipe-\(UUID().uuidString).sock"
        let server = SocketServer(path: path, queue: .main) { _ in }
        try server.start()
        let fd = try XCTUnwrap(UnixSocket.connect(path: path))
        server.stop() // close the peer end

        let payload = [UInt8]("x\n".utf8)
        var result = 0
        for _ in 0..<1000 {
            result = payload.withUnsafeBytes { write(fd, $0.baseAddress, payload.count) }
            if result <= 0 { break }
        }
        close(fd)
        // Reaching here at all proves no SIGPIPE killed us; the write must have
        // eventually failed (EPIPE) rather than succeeding forever.
        XCTAssertLessThanOrEqual(result, 0)
    }
}
