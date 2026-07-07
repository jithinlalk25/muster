import Foundation

public enum SocketError: Error, Equatable {
    case create(Int32)
    case bind(Int32)
    case listen(Int32)
}

/// Unix-domain-socket listener that decodes newline-delimited HookEvents.
///
/// Threading contract: `start()`, `stop()`, and all internal state are confined
/// to `queue` (the queue passed to `init`). Client accept/read handlers run on
/// `queue`, so `stop()` MUST be called on `queue` too — with the default `.main`
/// queue, call it on the main thread. Calling `start()`/`stop()` from another
/// thread traps via `dispatchPrecondition` in debug builds.
public final class SocketServer {
    public typealias Handler = (HookEvent) -> Void

    private let path: String
    private let queue: DispatchQueue
    private let handler: Handler
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]

    public init(path: String, queue: DispatchQueue = .main, handler: @escaping Handler) {
        self.path = path
        self.queue = queue
        self.handler = handler
    }

    /// Live client-connection count. Test/introspection only; read on `queue`.
    var clientCount: Int { clientSources.count }

    public func start() throws {
        dispatchPrecondition(condition: .onQueue(queue))
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        unlink(path) // clear any stale socket file

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketError.create(errno) }

        var addr = UnixSocket.makeSockaddr(path: path)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.stride))
            }
        }
        guard bindResult == 0 else { close(fd); throw SocketError.bind(errno) }
        guard listen(fd, 16) == 0 else { close(fd); throw SocketError.listen(errno) }
        listenFD = fd

        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler { [weak self] in self?.acceptClient() }
        src.resume()
        acceptSource = src
    }

    public func stop() {
        dispatchPrecondition(condition: .onQueue(queue))
        acceptSource?.cancel()
        acceptSource = nil
        clientSources.values.forEach { $0.cancel() }
        clientSources.removeAll()
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        unlink(path)
    }

    private func acceptClient() {
        let cfd = accept(listenFD, nil, nil)
        guard cfd >= 0 else { return }
        let framer = MessageFramer()
        let csrc = DispatchSource.makeReadSource(fileDescriptor: cfd, queue: queue)
        csrc.setEventHandler { [weak self] in
            guard let self else { return }
            var buf = [UInt8](repeating: 0, count: 4096)
            let n = read(cfd, &buf, buf.count)
            if n <= 0 { self.cancelClient(cfd); return }
            for line in framer.push(Data(buf[0..<n])) {
                if let ev = try? HookEvent.decode(wire: line) {
                    self.handler(ev)
                }
            }
        }
        csrc.setCancelHandler { close(cfd) }
        clientSources[cfd] = csrc
        csrc.resume()
    }

    private func cancelClient(_ cfd: Int32) {
        clientSources[cfd]?.cancel()
        clientSources[cfd] = nil
    }
}
