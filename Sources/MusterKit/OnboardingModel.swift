import Foundation
import Combine
import MusterCore

/// Drives the first-run setup screen: shows the settings.json diff, installs/uninstalls
/// Muster's hooks, and toggles launch-at-login. Main-thread only.
public final class OnboardingModel: ObservableObject {
    @Published public private(set) var isInstalled: Bool
    @Published public private(set) var diff: SettingsDiff
    @Published public var launchAtLogin: Bool
    @Published public private(set) var lastError: String?

    private let settings: SettingsStore
    private let binaryPath: String
    private let installer: HookInstaller
    private let launch: LaunchAtLoginControlling

    public init(settings: SettingsStore, binaryPath: String,
                installer: HookInstaller = HookInstaller(),
                launch: LaunchAtLoginControlling) {
        self.settings = settings
        self.binaryPath = binaryPath
        self.installer = installer
        self.launch = launch

        let current = settings.read()
        self.isInstalled = installer.isInstalled(in: current)
        self.diff = settings.makeDiff(before: current,
                                      after: installer.install(into: current, binaryPath: binaryPath))
        self.launchAtLogin = launch.isEnabled
        self.lastError = nil
    }

    /// Recompute state from disk (call when re-showing the screen).
    public func refresh() {
        let current = settings.read()
        isInstalled = installer.isInstalled(in: current)
        diff = settings.makeDiff(before: current,
                                 after: installer.install(into: current, binaryPath: binaryPath))
        launchAtLogin = launch.isEnabled
    }

    public func install() {
        lastError = nil
        do {
            let (after, _) = settings.proposedInstall(binaryPath: binaryPath, installer: installer)
            try settings.write(after)
            if launchAtLogin {
                do { try launch.setEnabled(true) } catch { lastError = "Login item: \(error)" }
            }
            isInstalled = true
            diff = settings.makeDiff(before: after, after: after) // now a no-op diff
        } catch {
            lastError = "Install failed: \(error)"
        }
    }

    public func uninstall() {
        lastError = nil
        do {
            let after = installer.uninstall(from: settings.read())
            try settings.write(after)
            // Only deregister the login item if it's actually enabled — symmetric with install(),
            // which only registers when the toggle is on. Avoids surfacing a login-item error when
            // the user never enabled launch-at-login (e.g. running an unregistered/raw binary).
            if launch.isEnabled {
                do { try launch.setEnabled(false) } catch { lastError = "Login item: \(error)" }
            }
            refresh()
        } catch {
            lastError = "Uninstall failed: \(error)"
        }
    }

    /// Apply the launch-at-login preference immediately, so the toggle is authoritative
    /// whether or not hooks are currently installed. Records any failure in lastError.
    public func setLaunch(_ enabled: Bool) {
        lastError = nil
        do { try launch.setEnabled(enabled) }
        catch { lastError = "Login item: \(error)" }
    }
}
