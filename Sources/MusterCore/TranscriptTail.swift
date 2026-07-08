import Foundation

/// Reads the last `maxBytes` of a file and returns it as UTF-8. When the read starts
/// mid-file, the partial leading line (and any split multi-byte char with it) is dropped
/// so the caller only sees whole lines. Decoding is lossy (best-effort) so a partial or
/// odd-boundary tail still yields content; `nil` is reserved for genuine I/O errors.
public enum TranscriptTail {
    public static func read(path: String, maxBytes: Int = 64 * 1024) -> String? {
        guard maxBytes > 0 else { return nil }
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
            return String(decoding: slice, as: UTF8.self)
        } catch {
            return nil
        }
    }
}
