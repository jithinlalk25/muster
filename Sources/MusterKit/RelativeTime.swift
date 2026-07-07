import Foundation

/// Compact relative time for session rows. Rounds to the nearest unit.
/// Never returns a negative/"in the future" phrasing.
public func relativeTime(from past: Date, to now: Date) -> String {
    let seconds = max(0, now.timeIntervalSince(past))
    if seconds < 45 { return "just now" }
    let minutes = Int((seconds / 60).rounded())
    if minutes < 60 { return "\(minutes)m" }
    let hours = Int((seconds / 3600).rounded())
    if hours < 24 { return "\(hours)h" }
    let days = Int((seconds / 86_400).rounded())
    return "\(days)d"
}
