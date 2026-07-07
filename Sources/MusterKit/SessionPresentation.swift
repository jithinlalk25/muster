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
