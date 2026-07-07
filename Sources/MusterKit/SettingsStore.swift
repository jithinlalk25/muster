import Foundation
import MusterCore

public struct SettingsDiff: Equatable {
    public let beforeJSON: String
    public let afterJSON: String
    public let addedLines: [String]
    public let removedLines: [String]

    public init(beforeJSON: String, afterJSON: String, addedLines: [String], removedLines: [String]) {
        self.beforeJSON = beforeJSON
        self.afterJSON = afterJSON
        self.addedLines = addedLines
        self.removedLines = removedLines
    }
}

/// Reads and writes ~/.claude/settings.json and computes the onboarding diff.
/// Pure merge logic is delegated to HookInstaller; this only does file I/O + presentation.
public struct SettingsStore {
    public let path: String
    public init(path: String) { self.path = path }

    public func read() -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: path),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return [:] }
        return obj
    }

    public func write(_ dict: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    public func proposedInstall(binaryPath: String,
                                installer: HookInstaller = HookInstaller()) -> (after: [String: Any], diff: SettingsDiff) {
        let before = read()
        let after = installer.install(into: before, binaryPath: binaryPath)
        return (after, makeDiff(before: before, after: after))
    }

    public func makeDiff(before: [String: Any], after: [String: Any]) -> SettingsDiff {
        let beforeJSON = Self.prettyJSON(before)
        let afterJSON = Self.prettyJSON(after)
        let beforeLines = beforeJSON.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let afterLines = afterJSON.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let beforeSet = Set(beforeLines)
        let afterSet = Set(afterLines)

        func isJSONBrace(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == "{" || trimmed == "}" || trimmed == "{}"
        }

        return SettingsDiff(
            beforeJSON: beforeJSON,
            afterJSON: afterJSON,
            addedLines: afterLines.filter { !beforeSet.contains($0) && !isJSONBrace($0) },
            removedLines: beforeLines.filter { !afterSet.contains($0) && !isJSONBrace($0) }
        )
    }

    public static func prettyJSON(_ obj: [String: Any]) -> String {
        guard !obj.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return "{}" }
        return s
    }
}
