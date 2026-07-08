import Foundation

/// Resolves the user's home directory.
///
/// `NSHomeDirectory()` reads the password database and ignores the `$HOME`
/// environment variable on macOS, which makes the app impossible to sandbox to a
/// scratch `HOME` for testing (it would always touch the real `~/.claude`). We prefer
/// `$HOME` when set — the Unix convention — and fall back to `NSHomeDirectory()`.
/// A normally-launched GUI app has `$HOME` set to the real home by launchd, so this
/// changes nothing in production.
public enum HomeDirectory {
    public static func resolved(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        if let home = environment["HOME"], !home.isEmpty { return home }
        return NSHomeDirectory()
    }
}
