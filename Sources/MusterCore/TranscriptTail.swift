import Foundation

/// Reads the last `maxBytes` of a file and returns it as UTF-8. When the read starts
/// mid-file, the partial leading line (and any split multi-byte char with it) is dropped
/// so the caller only sees whole lines. Returns nil on any I/O error.
public enum TranscriptTail {
    public static func read(path: String, maxBytes: Int = 64 * 1024) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        do {
            let end = try handle.seekToEnd()
            let start = end > UInt64(maxBytes) ? end - UInt64(maxBytes) : 0
            try handle.seek(toOffset: start)
            guard let data = try handle.readToEnd() else { return "" }
            var slice = data
            if start > 0, let nl = slice.firstIndex(of: 0x0A) {
                slice = slice.subdata(in: (nl + 1)..<slice.endIndex)
            }
            return String(data: slice, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
