import Foundation

public struct TranscriptMessage: Equatable, Sendable {
    public enum Role: String, Sendable { case user, assistant, other }
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

public struct TranscriptSummary: Equatable, Sendable {
    public var title: String?
    public var cwd: String?
    public var gitBranch: String?
    public var model: String?      // raw model id, e.g. "claude-opus-4-8"
    public var lastPrompt: String?

    public init(title: String? = nil, cwd: String? = nil, gitBranch: String? = nil,
                model: String? = nil, lastPrompt: String? = nil) {
        self.title = title
        self.cwd = cwd
        self.gitBranch = gitBranch
        self.model = model
        self.lastPrompt = lastPrompt
    }
}

public struct TranscriptReader {
    public init() {}

    public func parse(_ contents: String) -> (messages: [TranscriptMessage], title: String?) {
        var messages: [TranscriptMessage] = []
        var title: String?
        for obj in objects(contents) {
            switch obj["type"] as? String {
            case "ai-title":
                if let t = obj["aiTitle"] as? String { title = t } // last one wins
            case "user", "assistant":
                let msg = obj["message"] as? [String: Any]
                let roleStr = (msg?["role"] as? String) ?? "other"
                let role = TranscriptMessage.Role(rawValue: roleStr) ?? .other
                let text = Self.extractText(msg?["content"])
                if !text.isEmpty { messages.append(TranscriptMessage(role: role, text: text)) }
            default:
                break
            }
        }
        return (messages, title)
    }

    /// Single-pass digest of a transcript (or a tail of one). "Last wins" for values that
    /// change over the session; cwd is the first non-empty. lastPrompt prefers an explicit
    /// last-prompt record, else the most recent non-meta user message.
    public func summarize(_ contents: String) -> TranscriptSummary {
        var s = TranscriptSummary()
        var worktreeBranch: String?
        var lastUserHumanText: String?
        for obj in objects(contents) {
            if s.cwd == nil, let cwd = obj["cwd"] as? String, !cwd.isEmpty { s.cwd = cwd }
            if let br = obj["gitBranch"] as? String, !br.isEmpty { s.gitBranch = br }
            switch obj["type"] as? String {
            case "ai-title":
                if let t = obj["aiTitle"] as? String { s.title = t }
            case "last-prompt":
                if let p = obj["lastPrompt"] as? String, !p.isEmpty { s.lastPrompt = p }
            case "worktree-state":
                if let ws = obj["worktreeSession"] as? [String: Any],
                   let wb = ws["worktreeBranch"] as? String, !wb.isEmpty { worktreeBranch = wb }
            case "assistant":
                if let msg = obj["message"] as? [String: Any],
                   let m = msg["model"] as? String, !m.isEmpty { s.model = m }
            case "user":
                let isMeta = (obj["isMeta"] as? Bool) ?? false
                if !isMeta, let msg = obj["message"] as? [String: Any] {
                    let text = Self.extractText(msg["content"])
                    if !text.isEmpty { lastUserHumanText = text }
                }
            default:
                break
            }
        }
        if s.gitBranch == "HEAD", let worktreeBranch { s.gitBranch = worktreeBranch }
        if s.lastPrompt == nil { s.lastPrompt = lastUserHumanText }
        return s
    }

    public func firstCwd(_ contents: String) -> String? {
        for obj in objects(contents) {
            if let cwd = obj["cwd"] as? String, !cwd.isEmpty { return cwd }
        }
        return nil
    }

    private func objects(_ contents: String) -> [[String: Any]] {
        contents.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            guard let data = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { return nil }
            return obj
        }
    }

    static func extractText(_ content: Any?) -> String {
        if let s = content as? String { return s }
        guard let blocks = content as? [[String: Any]] else { return "" }
        var parts: [String] = []
        for b in blocks {
            switch b["type"] as? String {
            case "text":
                if let t = b["text"] as? String { parts.append(t) }
            case "tool_use":
                if let n = b["name"] as? String { parts.append("[tool: \(n)]") }
            case "tool_result":
                parts.append("[tool result]")
            default:
                break // ignore thinking + unknown
            }
        }
        return parts.joined(separator: "\n")
    }
}
