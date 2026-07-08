import Foundation

public enum NeedsReason: String, Codable, Equatable, Sendable {
    case yourTurn
    case permission
}

public enum SessionStatus: Equatable, Sendable {
    case working(activity: String?)
    case needsYou(reason: NeedsReason)
    case idle
}

public struct Session: Equatable, Identifiable, Sendable {
    public let id: String
    public var projectName: String
    public var cwd: String?
    public var transcriptPath: String?
    public var title: String?
    public var status: SessionStatus
    public var lastEventAt: Date
    public var currentTool: String?
    public var gitBranch: String?
    public var model: String?
    public var lastPrompt: String?

    public init(id: String, projectName: String, cwd: String? = nil,
                transcriptPath: String? = nil, title: String? = nil,
                status: SessionStatus, lastEventAt: Date, currentTool: String? = nil,
                gitBranch: String? = nil, model: String? = nil, lastPrompt: String? = nil) {
        self.id = id
        self.projectName = projectName
        self.cwd = cwd
        self.transcriptPath = transcriptPath
        self.title = title
        self.status = status
        self.lastEventAt = lastEventAt
        self.currentTool = currentTool
        self.gitBranch = gitBranch
        self.model = model
        self.lastPrompt = lastPrompt
    }
}

public func projectName(fromCwd cwd: String?) -> String {
    guard let cwd, !cwd.isEmpty else { return "unknown" }
    let name = (cwd as NSString).lastPathComponent
    return (name.isEmpty || name == "/") ? "unknown" : name
}
