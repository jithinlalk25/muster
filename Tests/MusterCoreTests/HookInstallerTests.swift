import XCTest
@testable import MusterCore

final class HookInstallerTests: XCTestCase {
    let bin = "/Applications/Muster.app/Contents/MacOS/muster-hook"

    func testInstallAddsAllEventsAndPreservesExisting() {
        let existing: [String: Any] = [
            "model": "opus",
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "/usr/bin/say done"]]]]]
        ]
        let out = HookInstaller().install(into: existing, binaryPath: bin)
        XCTAssertEqual(out["model"] as? String, "opus")
        let hooks = out["hooks"] as! [String: Any]
        XCTAssertEqual(Set(hooks.keys),
                       Set(EventKind.allCases.map(\.rawValue)))
        // existing Stop hook preserved alongside Muster's
        let stop = hooks["Stop"] as! [[String: Any]]
        let commands = stop.flatMap { ($0["hooks"] as! [[String: Any]]).compactMap { $0["command"] as? String } }
        XCTAssertTrue(commands.contains("/usr/bin/say done"))
        XCTAssertTrue(commands.contains { $0.contains("muster-hook") })
    }

    func testInstallIsIdempotent() {
        let once = HookInstaller().install(into: [:], binaryPath: bin)
        let twice = HookInstaller().install(into: once, binaryPath: bin)
        let stop = (twice["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let musterCount = stop.flatMap { ($0["hooks"] as! [[String: Any]]) }
            .filter { ($0["command"] as? String)?.contains("muster-hook") == true }.count
        XCTAssertEqual(musterCount, 1)
    }

    func testUninstallRemovesOnlyMusterAndPrunes() {
        let installed = HookInstaller().install(into: [
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "/usr/bin/say done"]]]]]
        ], binaryPath: bin)
        let out = HookInstaller().uninstall(from: installed)
        XCTAssertFalse(HookInstaller().isInstalled(in: out))
        // user's own Stop hook survives; Muster-only events pruned away
        let hooks = out["hooks"] as! [String: Any]
        XCTAssertNil(hooks["PreToolUse"])
        let stop = hooks["Stop"] as! [[String: Any]]
        let commands = stop.flatMap { ($0["hooks"] as! [[String: Any]]).compactMap { $0["command"] as? String } }
        XCTAssertEqual(commands, ["/usr/bin/say done"])
    }

    func testIsInstalled() {
        XCTAssertFalse(HookInstaller().isInstalled(in: [:]))
        let installed = HookInstaller().install(into: [:], binaryPath: bin)
        XCTAssertTrue(HookInstaller().isInstalled(in: installed))
    }
}
