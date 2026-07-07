import XCTest
import MusterCore
@testable import MusterKit

private final class FakeLaunch: LaunchAtLoginControlling {
    var enabled = false
    var isEnabled: Bool { enabled }
    func setEnabled(_ e: Bool) throws { enabled = e }
}

private final class ThrowingLaunch: LaunchAtLoginControlling {
    struct LoginError: Error {}
    var isEnabled: Bool { false }
    func setEnabled(_ e: Bool) throws { throw LoginError() }
}

final class OnboardingModelTests: XCTestCase {
    var path: String!
    let bin = "/Applications/Muster.app/Contents/MacOS/muster-hook"

    override func setUpWithError() throws {
        path = NSTemporaryDirectory() + "onboard-\(UUID().uuidString).json"
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: path)
    }

    fileprivate func makeModel(_ launch: FakeLaunch = FakeLaunch()) -> OnboardingModel {
        OnboardingModel(settings: SettingsStore(path: path), binaryPath: bin,
                        installer: HookInstaller(), launch: launch)
    }

    func testFreshStateNotInstalledWithDiff() {
        let model = makeModel()
        XCTAssertFalse(model.isInstalled)
        XCTAssertFalse(model.diff.addedLines.isEmpty)
    }

    func testInstallWritesHooksAndSetsFlags() {
        let launch = FakeLaunch()
        let model = makeModel(launch)
        model.launchAtLogin = true
        model.install()
        XCTAssertNil(model.lastError)
        XCTAssertTrue(model.isInstalled)
        XCTAssertTrue(HookInstaller().isInstalled(in: SettingsStore(path: path).read()))
        XCTAssertTrue(launch.enabled)
    }

    func testInstallWithoutLaunchLeavesLoginItemOff() {
        let launch = FakeLaunch()
        let model = makeModel(launch)
        model.launchAtLogin = false
        model.install()
        XCTAssertTrue(model.isInstalled)
        XCTAssertFalse(launch.enabled)
    }

    func testUninstallRemovesHooksAndLoginItem() {
        let launch = FakeLaunch()
        let model = makeModel(launch)
        model.launchAtLogin = true
        model.install()
        model.uninstall()
        XCTAssertFalse(model.isInstalled)
        XCTAssertFalse(HookInstaller().isInstalled(in: SettingsStore(path: path).read()))
        XCTAssertFalse(launch.enabled)
    }

    func testInstallWithLoginItemThrowsStillInstallsHooksAndRecordsError() {
        let model = OnboardingModel(settings: SettingsStore(path: path), binaryPath: bin,
                                    installer: HookInstaller(), launch: ThrowingLaunch())
        model.launchAtLogin = true
        model.install()
        XCTAssertNotNil(model.lastError)
        XCTAssertTrue(model.isInstalled)
        XCTAssertTrue(HookInstaller().isInstalled(in: SettingsStore(path: path).read()))
    }
}
