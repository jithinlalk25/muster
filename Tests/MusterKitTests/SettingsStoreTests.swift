import XCTest
import MusterCore
@testable import MusterKit

final class SettingsStoreTests: XCTestCase {
    var path: String!

    override func setUpWithError() throws {
        path = NSTemporaryDirectory() + "settings-\(UUID().uuidString).json"
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: path)
    }

    let bin = "/Applications/Muster.app/Contents/MacOS/muster-hook"

    func testReadMissingFileReturnsEmpty() {
        XCTAssertTrue(SettingsStore(path: path).read().isEmpty)
    }

    func testWriteThenReadRoundTrips() throws {
        let store = SettingsStore(path: path)
        try store.write(["model": "opus", "hooks": ["Stop": [["matcher": ""]]]])
        let back = store.read()
        XCTAssertEqual(back["model"] as? String, "opus")
        XCTAssertNotNil(back["hooks"])
    }

    func testProposedInstallDiffMentionsHookAndEvents() {
        let store = SettingsStore(path: path) // empty (missing file)
        let (after, diff) = store.proposedInstall(binaryPath: bin, installer: HookInstaller())
        XCTAssertTrue(HookInstaller().isInstalled(in: after))
        XCTAssertTrue(diff.addedLines.contains { $0.contains("muster-hook") })
        XCTAssertTrue(diff.addedLines.contains { $0.contains("Stop") })
        XCTAssertTrue(diff.removedLines.isEmpty)
    }

    func testWriteProposedThenUninstallClearsIt() throws {
        let store = SettingsStore(path: path)
        let (after, _) = store.proposedInstall(binaryPath: bin, installer: HookInstaller())
        try store.write(after)
        XCTAssertTrue(HookInstaller().isInstalled(in: store.read()))

        let cleaned = HookInstaller().uninstall(from: store.read())
        try store.write(cleaned)
        XCTAssertFalse(HookInstaller().isInstalled(in: store.read()))
    }

    func testPrettyJSONIsSortedAndStable() {
        let json = SettingsStore.prettyJSON(["b": 1, "a": 2])
        let aIndex = json.range(of: "\"a\"")!.lowerBound
        let bIndex = json.range(of: "\"b\"")!.lowerBound
        XCTAssertLessThan(aIndex, bIndex) // sorted keys
    }
}
