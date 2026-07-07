import XCTest
@testable import MusterCore

final class HookInstallerHardeningTests: XCTestCase {
    let bin = "/Applications/Muster.app/Contents/MacOS/muster-hook"

    /// command() must emit exactly `'<path>' <event>` (single-quoted path, one space).
    func testCommandLiteralFormat() {
        let cmd = HookInstaller().command(binaryPath: bin, event: "Stop")
        XCTAssertEqual(cmd, "'\(bin)' Stop")
    }

    /// A path containing a single quote is escaped POSIX-safely.
    func testCommandEscapesSingleQuote() {
        let cmd = HookInstaller().command(binaryPath: "/a'b/muster-hook", event: "PreToolUse")
        XCTAssertEqual(cmd, "'/a'\\''b/muster-hook' PreToolUse")
    }

    /// uninstall must prune ONLY Muster's command from an entry whose hooks array
    /// mixes a Muster command and a user command — the user command survives in place.
    func testUninstallPrunesMixedEntryKeepsUserCommand() {
        let mixed: [String: Any] = [
            "hooks": [
                "Stop": [[
                    "matcher": "",
                    "hooks": [
                        ["type": "command", "command": "'\(bin)' Stop"],
                        ["type": "command", "command": "/usr/bin/say done"],
                    ],
                ]],
            ],
        ]
        let out = HookInstaller().uninstall(from: mixed)
        XCTAssertFalse(HookInstaller().isInstalled(in: out))
        let stop = (out["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let commands = stop.flatMap { ($0["hooks"] as! [[String: Any]]).compactMap { $0["command"] as? String } }
        XCTAssertEqual(commands, ["/usr/bin/say done"])
    }
}
