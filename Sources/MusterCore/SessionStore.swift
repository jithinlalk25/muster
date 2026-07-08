import Foundation

public final class SessionStore {
    public private(set) var sessions: [String: Session] = [:]

    public init() {}

    /// Apply a hook event. Returns the resulting session, or nil if it was removed.
    @discardableResult
    public func apply(_ e: HookEvent) -> Session? {
        // An empty session id would key a phantom row that collapses distinct sessions
        // (and a blank-id SessionEnd could wipe it). Drop such events entirely.
        guard !e.sessionId.isEmpty else { return nil }

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
            // A `compact` SessionStart fires mid-turn (context compaction) and the session
            // keeps working; only a genuine startup/resume/clear should reset to idle.
            if e.source == "compact" {
                if sessions[e.sessionId] == nil { s.status = .working(activity: nil) }
                // otherwise preserve the existing (carried-over) status
            } else {
                s.status = .idle
            }
        case .userPromptSubmit:
            s.currentTool = nil
            s.status = .working(activity: nil)
        case .preToolUse:
            s.currentTool = e.toolName
            s.status = .working(activity: e.toolName.map { "Running: \($0)" })
        case .postToolUse:
            s.currentTool = nil
            s.status = .working(activity: e.toolName.map { "Ran: \($0)" })
        case .notification:
            s.status = .needsYou(reason: Self.notificationReason(e.message))
        case .stop:
            s.currentTool = nil
            s.status = .needsYou(reason: .yourTurn)
        case .subagentStop:
            // A subagent returned; the main agent is thinking again. Don't reuse the
            // last tool name — it usually points at an already-finished tool call.
            s.status = .working(activity: nil)
        case .sessionEnd:
            break // handled above
        }

        sessions[e.sessionId] = s
        return s
    }

    /// Classify a Notification event. Claude Code fires Notification for two distinct
    /// cases: a tool-permission request ("… needs your permission to use …") and the
    /// ~60s idle prompt ("Claude is waiting for your input"). Only the former is a
    /// permission gate; everything else (including a missing message) means the session
    /// is simply waiting on the user.
    static func notificationReason(_ message: String?) -> NeedsReason {
        guard let message, message.lowercased().contains("permission") else { return .yourTurn }
        return .permission
    }

    /// Insert a session discovered by a launch-time disk scan, but only if no live
    /// session with that id already exists. Never overwrites hook-driven state.
    public func seed(_ session: Session) {
        if sessions[session.id] == nil {
            sessions[session.id] = session
        }
    }

    /// Merge transcript-derived fields into an existing session. Non-nil values only, and
    /// never touches hook-owned state (status, currentTool, lastEventAt). No-op if absent.
    public func enrich(_ id: String, gitBranch: String?, model: String?,
                       lastPrompt: String?, title: String?) {
        guard var s = sessions[id] else { return }
        if let gitBranch { s.gitBranch = gitBranch }
        if let model { s.model = model }
        if let lastPrompt { s.lastPrompt = lastPrompt }
        if let title { s.title = title }
        sessions[id] = s
    }

    /// Reconcile the store against the pid-files whose process is currently alive (the
    /// caller has already filtered by liveness). Seeds unseen live sessions, promotes a
    /// stale-idle row to working when the pid-file says busy, refreshes the human name,
    /// and prunes any pid-backed row whose process is gone. Never demotes, and never
    /// overwrites `needsYou`/`working`. `transcriptPath` supplies a derived path for newly
    /// seeded rows (keeps projects-dir knowledge out of the store). Returns pruned ids.
    @discardableResult
    public func applyPidSessions(_ alive: [PidSession], now: Date,
                                 transcriptPath: (PidSession) -> String?) -> [String] {
        let aliveIds = Set(alive.map { $0.sessionId })
        for p in alive {
            if var s = sessions[p.sessionId] {
                s.name = p.name
                s.pid = p.pid
                if p.status == .busy {
                    // A busy pid-file is fresh evidence of activity: heartbeat lastEventAt so the
                    // quiet-timer in age() never demotes a genuinely-working row (no flapping). A
                    // pid `idle` reading deliberately does NOT heartbeat, so age() can still fall
                    // back to demoting a row whose Stop hook was missed.
                    s.lastEventAt = now
                    if case .idle = s.status { s.status = .working(activity: nil) }  // promote-only
                }
                sessions[p.sessionId] = s
            } else {
                sessions[p.sessionId] = Session(
                    id: p.sessionId,
                    projectName: projectName(fromCwd: p.cwd),
                    cwd: p.cwd,
                    transcriptPath: transcriptPath(p),
                    status: p.status == .busy ? .working(activity: nil) : .idle,
                    lastEventAt: p.status == .busy ? now : p.statusUpdatedAt,
                    name: p.name,
                    pid: p.pid
                )
            }
        }
        var removed: [String] = []
        for (id, s) in sessions where s.pid != nil && !aliveIds.contains(id) {
            sessions[id] = nil
            removed.append(id)
        }
        return removed
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
                // A tool still in flight (PreToolUse seen, PostToolUse not yet) means the
                // session is genuinely busy even though no events fire during a long call.
                if quiet >= idleAfter, s.currentTool == nil {
                    var u = s
                    u.status = .idle
                    sessions[id] = u
                }
            case .idle:
                if s.pid == nil, quiet >= idleAfter + dropAfter {
                    sessions[id] = nil
                    removed.append(id)
                }
            }
        }
        return removed
    }
}
