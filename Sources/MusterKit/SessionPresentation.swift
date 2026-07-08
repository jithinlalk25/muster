import Foundation
import MusterCore

public enum StatusDot: Equatable {
    case working
    case needsYou
    case idle
}

public func dot(for status: SessionStatus) -> StatusDot {
    switch status {
    case .working: return .working
    case .needsYou: return .needsYou
    case .idle: return .idle
    }
}

public func statusLabel(for status: SessionStatus) -> String {
    switch status {
    case .working: return "Working"
    case .needsYou(.yourTurn): return "Your turn"
    case .needsYou(.permission): return "Permission"
    case .idle: return "Idle"
    }
}

/// Display order: Needs-you, then Working, then Idle; newest lastEventAt first within a group.
public func sortedForDisplay(_ sessions: [Session]) -> [Session] {
    sessions.sorted { a, b in
        let ra = groupRank(a.status), rb = groupRank(b.status)
        if ra != rb { return ra < rb }
        return a.lastEventAt > b.lastEventAt
    }
}

private func groupRank(_ status: SessionStatus) -> Int {
    switch status {
    case .needsYou: return 0
    case .working: return 1
    case .idle: return 2
    }
}

public struct BadgeState: Equatable {
    public let needsYouCount: Int
    public init(needsYouCount: Int) { self.needsYouCount = needsYouCount }
    public var isAlert: Bool { needsYouCount > 0 }
}

public func badgeState(for sessions: [Session]) -> BadgeState {
    let count = sessions.filter {
        if case .needsYou = $0.status { return true } else { return false }
    }.count
    return BadgeState(needsYouCount: count)
}

/// Map a raw Claude model id to a short display name; nil when there is nothing useful
/// to show. Unknown ids pass through unchanged so a new model still renders something.
public func shortModelName(_ id: String?) -> String? {
    guard let id, !id.isEmpty, id != "<synthetic>" else { return nil }
    if id.contains("opus") { return "opus" }
    if id.contains("sonnet") { return "sonnet" }
    if id.contains("haiku") { return "haiku" }
    if id.contains("fable") { return "fable" }
    return id
}

/// The metadata line under the project name: "branch · model" with missing parts elided.
/// Returns nil when there is nothing to show.
public func metaLine(for session: Session) -> String? {
    let parts = [session.gitBranch, session.model]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}

/// The third row line: the live activity while working, else the last prompt, else the
/// ai-title, else the status label.
public func subtitle(for session: Session) -> String {
    if case let .working(activity) = session.status, let activity, !activity.isEmpty {
        return activity
    }
    if let p = session.lastPrompt, !p.isEmpty { return p }
    if let t = session.title, !t.isEmpty { return t }
    return statusLabel(for: session.status)
}

/// The folder to reveal for a session (its working directory), or nil if unknown.
public func revealTarget(for session: Session) -> URL? {
    guard let cwd = session.cwd, !cwd.isEmpty else { return nil }
    return URL(fileURLWithPath: cwd)
}

/// The row's primary label: the pid-file's human name (e.g. "muster-56") when present,
/// otherwise the project folder name. The name disambiguates multiple sessions in one folder.
public func primaryLabel(for session: Session) -> String {
    if let name = session.name, !name.isEmpty { return name }
    return session.projectName
}
