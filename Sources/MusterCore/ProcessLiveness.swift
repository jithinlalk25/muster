import Foundation

/// Whether a process is currently alive. Injected so tests never spawn real processes.
public protocol ProcessLiveness {
    func isAlive(_ pid: Int32) -> Bool
}

/// Real liveness via `kill(pid, 0)`: 0 → the process exists; `ESRCH` → gone; `EPERM` (it
/// exists but we may not signal it) → treated as **alive**, so we never prune a process we
/// merely lack permission to probe.
public struct DefaultProcessLiveness: ProcessLiveness {
    public init() {}

    public func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }
}
