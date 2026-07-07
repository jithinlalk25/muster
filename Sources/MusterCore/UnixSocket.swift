import Foundation

public enum UnixSocket {
    /// Fill a sockaddr_un for the given path (truncated to the platform limit).
    public static func makeSockaddr(path: String) -> sockaddr_un {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let cap = MemoryLayout.size(ofValue: addr.sun_path)
        path.withCString { cs in
            withUnsafeMutablePointer(to: &addr.sun_path) { p in
                p.withMemoryRebound(to: CChar.self, capacity: cap) { dst in
                    _ = strncpy(dst, cs, cap - 1)
                }
            }
        }
        return addr
    }

    /// Connect to a listening Unix socket. Returns a connected fd, or nil on failure.
    ///
    /// Disables SIGPIPE on the connected socket (`SO_NOSIGPIPE`) so that writes to a
    /// peer that has already closed fail with `EPIPE` (return -1) instead of raising
    /// SIGPIPE and killing the process.
    public static func connect(path: String) -> Int32? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var addr = makeSockaddr(path: path)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.stride))
            }
        }
        if result != 0 { close(fd); return nil }
        return fd
    }
}
