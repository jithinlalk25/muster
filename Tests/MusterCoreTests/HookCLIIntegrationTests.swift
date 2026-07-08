import XCTest
@testable import MusterCore

final class HookCLIIntegrationTests: XCTestCase {
    /// Locate the built muster-hook binary next to the test bundle.
    private func hookBinaryURL() throws -> URL {
        let bundleDir = Bundle(for: type(of: self)).bundleURL.deletingLastPathComponent()
        let candidate = bundleDir.appendingPathComponent("muster-hook")
        guard FileManager.default.isExecutableFile(atPath: candidate.path) else {
            throw XCTSkip("muster-hook binary not found at \(candidate.path); run `swift build` first")
        }
        return candidate
    }

    func testCLIForwardsEventToSocket() throws {
        let binary = try hookBinaryURL()
        let path = NSTemporaryDirectory() + "muster-cli-\(UUID().uuidString).sock"

        let received = expectation(description: "server received event")
        var got: HookEvent?
        let server = SocketServer(path: path, queue: .main) { ev in got = ev; received.fulfill() }
        try server.start()
        defer { server.stop() }

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["PreToolUse"]
        proc.environment = ["MUSTER_SOCKET": path]
        let stdin = Pipe()
        proc.standardInput = stdin
        try proc.run()
        let json = #"{"session_id":"s9","cwd":"/p/muster","tool_name":"Bash"}"#
        stdin.fileHandleForWriting.write(Data(json.utf8))
        stdin.fileHandleForWriting.closeFile()
        proc.waitUntilExit()

        wait(for: [received], timeout: 3.0)
        XCTAssertEqual(proc.terminationStatus, 0)
        XCTAssertEqual(got?.event, .preToolUse)
        XCTAssertEqual(got?.sessionId, "s9")
        XCTAssertEqual(got?.toolName, "Bash")
    }

    func testCLIDropsEventWithEmptySessionId() throws {
        let binary = try hookBinaryURL()
        let path = NSTemporaryDirectory() + "muster-cli-\(UUID().uuidString).sock"

        let notReceived = expectation(description: "server received nothing")
        notReceived.isInverted = true
        var got: HookEvent?
        let server = SocketServer(path: path, queue: .main) { ev in got = ev; notReceived.fulfill() }
        try server.start()
        defer { server.stop() }

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["PreToolUse"]
        proc.environment = ["MUSTER_SOCKET": path]
        let stdin = Pipe()
        proc.standardInput = stdin
        try proc.run()
        stdin.fileHandleForWriting.write(Data(#"{"session_id":"","tool_name":"Bash"}"#.utf8))
        stdin.fileHandleForWriting.closeFile()
        proc.waitUntilExit()

        XCTAssertEqual(proc.terminationStatus, 0) // still fail-open
        wait(for: [notReceived], timeout: 1.0)
        XCTAssertNil(got, "hook must not forward an event with an empty session id")
    }

    func testCLIFailsOpenWithNoServer() throws {
        let binary = try hookBinaryURL()
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["Stop"]
        proc.environment = ["MUSTER_SOCKET": NSTemporaryDirectory() + "does-not-exist.sock"]
        let stdin = Pipe()
        proc.standardInput = stdin
        try proc.run()
        stdin.fileHandleForWriting.write(Data("{}".utf8))
        stdin.fileHandleForWriting.closeFile()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 0) // fail-open
    }
}
