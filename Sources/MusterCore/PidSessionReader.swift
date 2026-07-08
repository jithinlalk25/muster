import Foundation

/// Reads the pid-files under `~/.claude/sessions`. Injected into the view-model so tests
/// supply a fixture directory instead of touching the real `~/.claude`.
public protocol PidSessionReading {
    /// The decoded pid-files, or `nil` if the sessions directory could not be listed (a
    /// transient or absent read). The caller MUST skip reconciliation on `nil`, so a failed
    /// read never prunes live rows. An empty array means the directory listed cleanly with no
    /// valid pid-files (dead sessions) — a legitimate prune signal.
    func read() -> [PidSession]?
}

/// Decodes every `<pid>.json` in `sessionsDir`, silently skipping any that are malformed or
/// carry an empty session id. An unlistable directory → `nil`. Never throws.
public struct PidSessionReader: PidSessionReading {
    private let sessionsDir: String
    private let fileManager: FileManager

    public init(sessionsDir: String, fileManager: FileManager = .default) {
        self.sessionsDir = sessionsDir
        self.fileManager = fileManager
    }

    public func read() -> [PidSession]? {
        guard let files = try? fileManager.contentsOfDirectory(atPath: sessionsDir) else { return nil }
        let decoder = JSONDecoder()
        var out: [PidSession] = []
        for file in files where file.hasSuffix(".json") {
            let full = sessionsDir + "/" + file
            guard let data = fileManager.contents(atPath: full),
                  let parsed = try? decoder.decode(PidSession.self, from: data),
                  !parsed.sessionId.isEmpty else { continue }
            out.append(parsed)
        }
        return out
    }
}
