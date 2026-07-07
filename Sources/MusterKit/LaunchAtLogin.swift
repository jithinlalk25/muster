import Foundation
import ServiceManagement

/// Abstraction over the login-item API so onboarding logic is testable.
public protocol LaunchAtLoginControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Real implementation backed by SMAppService (macOS 13+). Only valid for a
/// properly bundled .app; under `swift run` register() may throw — callers surface it.
public struct SystemLaunchAtLogin: LaunchAtLoginControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
