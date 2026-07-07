import Foundation

public final class SessionStore {
    public private(set) var sessions: [String: Session] = [:]

    public init() {}

    /// Apply a hook event. Returns the resulting session, or nil if it was removed.
    @discardableResult
    public func apply(_ e: HookEvent) -> Session? {
        if e.event == .sessionEnd {
            sessions[e.sessionId] = nil
            return nil
        }

        var s = sessions[e.sessionId] ?? Session(
            id: e.sessionId,
            projectName: projectName(fromCwd: e.cwd),
            cwd: e.cwd,
            transcriptPath: e.transcriptPath,
            title: nil,
            status: .idle,
            lastEventAt: e.timestamp
        )

        if let cwd = e.cwd { s.cwd = cwd; s.projectName = projectName(fromCwd: cwd) }
        if let tp = e.transcriptPath { s.transcriptPath = tp }
        s.lastEventAt = e.timestamp

        switch e.event {
        case .sessionStart:
            s.status = .idle
        case .userPromptSubmit:
            s.currentTool = nil
            s.status = .working(activity: nil)
        case .preToolUse:
            s.currentTool = e.toolName
            s.status = .working(activity: e.toolName.map { "Running: \($0)" })
        case .postToolUse:
            s.status = .working(activity: e.toolName.map { "Ran: \($0)" })
        case .notification:
            s.status = .needsYou(reason: .permission)
        case .stop:
            s.currentTool = nil
            s.status = .needsYou(reason: .yourTurn)
        case .subagentStop:
            s.status = .working(activity: s.currentTool.map { "Running: \($0)" })
        case .sessionEnd:
            break // handled above
        }

        sessions[e.sessionId] = s
        return s
    }

    /// Insert a session discovered by a launch-time disk scan, but only if no live
    /// session with that id already exists. Never overwrites hook-driven state.
    public func seed(_ session: Session) {
        if sessions[session.id] == nil {
            sessions[session.id] = session
        }
    }

    /// Advance liveness. Returns ids removed this call.
    @discardableResult
    public func age(now: Date, idleAfter: TimeInterval, dropAfter: TimeInterval) -> [String] {
        var removed: [String] = []
        for (id, s) in sessions {
            let quiet = now.timeIntervalSince(s.lastEventAt)
            switch s.status {
            case .needsYou:
                continue // never ages out on its own
            case .working:
                if quiet >= idleAfter {
                    var u = s
                    u.status = .idle
                    sessions[id] = u
                }
            case .idle:
                if quiet >= idleAfter + dropAfter {
                    sessions[id] = nil
                    removed.append(id)
                }
            }
        }
        return removed
    }
}
