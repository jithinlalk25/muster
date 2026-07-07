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
