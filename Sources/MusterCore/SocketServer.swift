import Foundation

public enum SocketError: Error, Equatable {
    case create(Int32)
    case bind(Int32)
    case listen(Int32)
}

public final class SocketServer {
    public typealias Handler = (HookEvent) -> Void

    private let path: String
    private let queue: DispatchQueue
    private let handler: Handler
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clientSources: [DispatchSourceRead] = []

    public init(path: String, queue: DispatchQueue = .main, handler: @escaping Handler) {
        self.path = path
        self.queue = queue
        self.handler = handler
    }

    public func start() throws {
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
        acceptSource?.cancel()
        acceptSource = nil
        clientSources.forEach { $0.cancel() }
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
            var buf = [UInt8](repeating: 0, count: 4096)
            let n = read(cfd, &buf, buf.count)
            if n <= 0 { csrc.cancel(); return }
            for line in framer.push(Data(buf[0..<n])) {
                if let ev = try? HookEvent.decode(wire: line) {
                    self?.handler(ev)
                }
            }
        }
        csrc.setCancelHandler { close(cfd) }
        csrc.resume()
        clientSources.append(csrc)
    }
}
