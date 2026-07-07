import Foundation

public final class MessageFramer {
    private var buffer = Data()

    public init() {}

    /// Append bytes; return any complete newline-delimited messages (newline stripped).
    public func push(_ data: Data) -> [Data] {
        buffer.append(data)
        var out: [Data] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            if !line.isEmpty { out.append(Data(line)) }
            buffer = Data(buffer[buffer.index(after: nl)...])
        }
        return out
    }
}
