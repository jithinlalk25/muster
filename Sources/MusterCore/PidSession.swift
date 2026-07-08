import Foundation

public enum PidStatus: String, Sendable {
    case busy
    case idle
}

/// A parsed `~/.claude/sessions/<pid>.json` file. Claude Code writes one per live
/// interactive session; `status` is authoritative busy/idle and `sessionId` joins to the
/// store (which is keyed by session id). Only the fields Muster uses are decoded — unknown
/// keys are ignored, a missing/unrecognized `status` degrades to `.idle`, and
/// `statusUpdatedAt` is converted from epoch-milliseconds.
public struct PidSession: Equatable, Sendable, Decodable {
    public let pid: Int32
    public let sessionId: String
    public let cwd: String?
    public let name: String?
    public let status: PidStatus
    public let statusUpdatedAt: Date

    public init(pid: Int32, sessionId: String, cwd: String?, name: String?,
                status: PidStatus, statusUpdatedAt: Date) {
        self.pid = pid
        self.sessionId = sessionId
        self.cwd = cwd
        self.name = name
        self.status = status
        self.statusUpdatedAt = statusUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case pid, sessionId, cwd, name, status, statusUpdatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawPid = try c.decode(Int.self, forKey: .pid)
        guard let pid32 = Int32(exactly: rawPid) else {
            throw DecodingError.dataCorruptedError(forKey: .pid, in: c,
                debugDescription: "pid out of Int32 range")
        }
        self.pid = pid32
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        let rawStatus = try c.decodeIfPresent(String.self, forKey: .status)
        self.status = PidStatus(rawValue: rawStatus ?? "idle") ?? .idle
        let ms = try c.decodeIfPresent(Double.self, forKey: .statusUpdatedAt) ?? 0
        self.statusUpdatedAt = Date(timeIntervalSince1970: ms / 1000)
    }
}
