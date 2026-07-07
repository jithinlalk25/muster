import Foundation

public enum EventKind: String, Codable, Sendable, CaseIterable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case notification = "Notification"
    case stop = "Stop"
    case subagentStop = "SubagentStop"
    case sessionEnd = "SessionEnd"
}

public struct HookEvent: Codable, Equatable, Sendable {
    public let event: EventKind
    public let sessionId: String
    public var cwd: String?
    public var transcriptPath: String?
    public var toolName: String?
    public var message: String?
    public var timestamp: Date

    public init(event: EventKind, sessionId: String, cwd: String? = nil,
                transcriptPath: String? = nil, toolName: String? = nil,
                message: String? = nil, timestamp: Date) {
        self.event = event
        self.sessionId = sessionId
        self.cwd = cwd
        self.transcriptPath = transcriptPath
        self.toolName = toolName
        self.message = message
        self.timestamp = timestamp
    }
}

public extension HookEvent {
    func wireLine() throws -> Data {
        var d = try Wire.encoder().encode(self)
        d.append(0x0A) // "\n"
        return d
    }

    static func decode(wire: Data) throws -> HookEvent {
        try Wire.decoder().decode(HookEvent.self, from: wire)
    }
}

public enum MusterError: Error, Equatable {
    case unknownEvent(String)
}

public extension HookEvent {
    /// Build a HookEvent from the raw JSON Claude Code writes to a hook's stdin.
    /// Tolerates missing/extra fields; `timestamp` is stamped by the caller.
    static func fromClaudeStdin(eventName: String, data: Data, timestamp: Date) throws -> HookEvent {
        guard let kind = EventKind(rawValue: eventName) else {
            throw MusterError.unknownEvent(eventName)
        }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        func str(_ key: String) -> String? { obj[key] as? String }
        return HookEvent(
            event: kind,
            sessionId: str("session_id") ?? "",
            cwd: str("cwd"),
            transcriptPath: str("transcript_path"),
            toolName: str("tool_name"),
            message: str("message"),
            timestamp: timestamp
        )
    }
}
