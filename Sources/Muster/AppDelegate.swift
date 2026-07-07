import AppKit
import SwiftUI
import MusterCore
import MusterKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: SessionViewModel!
    private var statusItem: StatusItemController!
    private var panel: PanelController!
    private var onboardingWindow: NSWindow?

    private let home = NSHomeDirectory()

    private var socketPath: String {
        ProcessInfo.processInfo.environment["MUSTER_SOCKET"] ?? (home + "/.muster/muster.sock")
    }
    private var projectsDir: String { home + "/.claude/projects" }
    private var settingsPath: String { home + "/.claude/settings.json" }

    /// The muster-hook binary sits next to this executable (bundle MacOS dir or .build/<config>).
    private var hookBinaryPath: String {
        let exeDir = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .deletingLastPathComponent()
        return exeDir.appendingPathComponent("muster-hook").path
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = SessionViewModel(socketPath: socketPath, projectsDir: projectsDir)
        vm.start(now: Date())
        self.viewModel = vm

        let panel = PanelController(vm: vm)
        self.panel = panel

        let statusItem = StatusItemController(vm: vm) { [weak panel] button in
            panel?.toggle(relativeTo: button)
        }
        self.statusItem = statusItem

        if !HookInstaller().isInstalled(in: SettingsStore(path: settingsPath).read()) {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
    }

    private func showOnboarding() {
        let model = OnboardingModel(
            settings: SettingsStore(path: settingsPath),
            binaryPath: hookBinaryPath,
            installer: HookInstaller(),
            launch: SystemLaunchAtLogin()
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Muster Setup"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView(model: model) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        })
        self.onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
