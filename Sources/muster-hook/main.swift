import Foundation
import MusterCore

// Usage: muster-hook <EventName>   (Claude JSON on stdin)
// Fail-open: any problem -> exit(0) silently, never blocking Claude Code.

let args = CommandLine.arguments
guard args.count >= 2 else { exit(0) }
let eventName = args[1]

let socketPath = ProcessInfo.processInfo.environment["MUSTER_SOCKET"]
    ?? (HomeDirectory.resolved() + "/.muster/muster.sock")

// readToEnd() throws a catchable Swift error on I/O failure (fail-open); the older
// readDataToEndOfFile() throws an *uncatchable* ObjC exception that would crash the hook.
let stdinData = (try? FileHandle.standardInput.readToEnd()) ?? Data()

guard let event = try? HookEvent.fromClaudeStdin(eventName: eventName, data: stdinData, timestamp: Date()),
      !event.sessionId.isEmpty, // nothing to attribute an empty-id event to; drop it
      let line = try? event.wireLine(),
      let fd = UnixSocket.connect(path: socketPath) else {
    exit(0)
}

line.withUnsafeBytes { raw in
    _ = write(fd, raw.baseAddress, line.count)
}
close(fd)
exit(0)
