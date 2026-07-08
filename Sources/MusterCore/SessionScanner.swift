import Foundation

public struct ScannedSession: Equatable, Sendable {
    public let id: String
    public let path: String
    public let modifiedAt: Date
    public var title: String?
    public var cwd: String?
    public var gitBranch: String?
    public var model: String?       // raw model id
    public var lastPrompt: String?

    public init(id: String, path: String, modifiedAt: Date, title: String? = nil,
                cwd: String? = nil, gitBranch: String? = nil, model: String? = nil,
                lastPrompt: String? = nil) {
        self.id = id
        self.path = path
        self.modifiedAt = modifiedAt
        self.title = title
        self.cwd = cwd
        self.gitBranch = gitBranch
        self.model = model
        self.lastPrompt = lastPrompt
    }
}

public struct SessionScanner {
    private let projectsDir: String
    private let reader = TranscriptReader()

    public init(projectsDir: String) {
        self.projectsDir = projectsDir
    }

    public func scan(now: Date, within: TimeInterval, fileManager: FileManager = .default) -> [ScannedSession] {
        guard let projects = try? fileManager.contentsOfDirectory(atPath: projectsDir) else { return [] }
        var results: [ScannedSession] = []
        for project in projects {
            let dir = projectsDir + "/" + project
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let full = dir + "/" + file
                guard let attrs = try? fileManager.attributesOfItem(atPath: full),
                      let mtime = attrs[.modificationDate] as? Date,
                      now.timeIntervalSince(mtime) <= within else { continue }
                let id = String(file.dropLast(".jsonl".count))
                var scanned = ScannedSession(id: id, path: full, modifiedAt: mtime)
                if let contents = try? String(contentsOfFile: full, encoding: .utf8) {
                    let summary = reader.summarize(contents)
                    scanned.title = summary.title
                    scanned.cwd = summary.cwd
                    scanned.gitBranch = summary.gitBranch
                    scanned.model = summary.model
                    scanned.lastPrompt = summary.lastPrompt
                }
                results.append(scanned)
            }
        }
        return results.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}
