import Foundation
import MusterCore

// Usage: muster-hook <EventName>   (Claude JSON on stdin)
// Fail-open: any problem -> exit(0) silently, never blocking Claude Code.

let args = CommandLine.arguments
guard args.count >= 2 else { exit(0) }
let eventName = args[1]

let socketPath = ProcessInfo.processInfo.environment["MUSTER_SOCKET"]
    ?? (HomeDirectory.resolved() + "/.muster/muster.sock")

let stdinData = FileHandle.standardInput.readDataToEndOfFile()

guard let event = try? HookEvent.fromClaudeStdin(eventName: eventName, data: stdinData, timestamp: Date()),
      let line = try? event.wireLine(),
      let fd = UnixSocket.connect(path: socketPath) else {
    exit(0)
}

line.withUnsafeBytes { raw in
    _ = write(fd, raw.baseAddress, line.count)
}
close(fd)
exit(0)
