import Foundation

public struct HookInstaller {
    public let events: [String]

    public init(events: [String] = EventKind.allCases.map(\.rawValue)) {
        self.events = events
    }

    public func command(binaryPath: String, event: String) -> String {
        "\(shellQuote(binaryPath)) \(event)"
    }

    /// Merge Muster's hooks into a settings dict. Idempotent and non-destructive.
    public func install(into settings: [String: Any], binaryPath: String) -> [String: Any] {
        var s = settings
        var hooks = (s["hooks"] as? [String: Any]) ?? [:]
        for event in events {
            var entries = (hooks[event] as? [[String: Any]]) ?? []
            entries = entries.filter { !entryIsMuster($0) } // drop stale muster entries
            entries.append([
                "matcher": "",
                "hooks": [["type": "command", "command": command(binaryPath: binaryPath, event: event)]]
            ])
            hooks[event] = entries
        }
        s["hooks"] = hooks
        return s
    }

    public func uninstall(from settings: [String: Any]) -> [String: Any] {
        var s = settings
        guard var hooks = s["hooks"] as? [String: Any] else { return s }
        for (event, val) in hooks {
            guard let entries = val as? [[String: Any]] else { continue }
            let kept: [[String: Any]] = entries.compactMap { entry in
                var e = entry
                let hookList = ((e["hooks"] as? [[String: Any]]) ?? [])
                    .filter { !commandIsMuster($0["command"] as? String) }
                if hookList.isEmpty { return nil }
                e["hooks"] = hookList
                return e
            }
            if kept.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
        }
        if hooks.isEmpty { s["hooks"] = nil } else { s["hooks"] = hooks }
        return s
    }

    public func isInstalled(in settings: [String: Any]) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { val in
            (val as? [[String: Any]])?.contains { entryIsMuster($0) } ?? false
        }
    }

    // MARK: - Helpers

    private func entryIsMuster(_ entry: [String: Any]) -> Bool {
        ((entry["hooks"] as? [[String: Any]]) ?? [])
            .contains { commandIsMuster($0["command"] as? String) }
    }

    private func commandIsMuster(_ command: String?) -> Bool {
        (command ?? "").contains("muster-hook")
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
