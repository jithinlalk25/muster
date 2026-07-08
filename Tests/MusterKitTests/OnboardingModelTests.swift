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

    func testUninstallDoesNotTouchLoginItemWhenNeverEnabled() {
        // Mirrors the raw-binary env: login item was never enabled and deregister would throw.
        // Uninstalling hooks must not surface a scary login-item error when the user never
        // turned launch-at-login on.
        let model = OnboardingModel(settings: SettingsStore(path: path), binaryPath: bin,
                                    installer: HookInstaller(), launch: ThrowingLaunch())
        model.install()
        XCTAssertTrue(model.isInstalled)
        XCTAssertNil(model.lastError)

        model.uninstall()
        XCTAssertFalse(model.isInstalled, "hooks should still be removed")
        XCTAssertFalse(HookInstaller().isInstalled(in: SettingsStore(path: path).read()))
        XCTAssertNil(model.lastError, "must not deregister (or error on) a login item that was never enabled")
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

    func testSetLaunchAppliesToLoginItem() {
        let launch = FakeLaunch()
        let model = makeModel(launch)
        model.setLaunch(true)
        XCTAssertTrue(launch.enabled)
        XCTAssertNil(model.lastError)
        model.setLaunch(false)
        XCTAssertFalse(launch.enabled)
    }

    func testSetLaunchRecordsErrorOnThrow() {
        let model = OnboardingModel(settings: SettingsStore(path: path), binaryPath: bin,
                                    installer: HookInstaller(), launch: ThrowingLaunch())
        model.setLaunch(true)
        XCTAssertNotNil(model.lastError)
    }
}
