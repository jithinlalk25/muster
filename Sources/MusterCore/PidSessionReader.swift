import Foundation

/// Reads the pid-files under `~/.claude/sessions`. Injected into the view-model so tests
/// supply a fixture directory instead of touching the real `~/.claude`.
public protocol PidSessionReading {
    func read() -> [PidSession]
}

/// Decodes every `<pid>.json` in `sessionsDir`, silently skipping any that are malformed or
/// carry an empty session id. Missing directory → empty. Never throws.
public struct PidSessionReader: PidSessionReading {
    private let sessionsDir: String
    private let fileManager: FileManager

    public init(sessionsDir: String, fileManager: FileManager = .default) {
        self.sessionsDir = sessionsDir
        self.fileManager = fileManager
    }

    public func read() -> [PidSession] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: sessionsDir) else { return [] }
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
