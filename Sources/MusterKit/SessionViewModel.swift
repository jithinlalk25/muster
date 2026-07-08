import Foundation
import Combine
import MusterCore

/// Derive a session's transcript path from its cwd, matching Claude's project-dir slug
/// (every `/` becomes `-`). Lets a pid-seeded row be enriched like any other. Returns nil
/// when the cwd is unknown; if the derived path is wrong (e.g. a cwd with dots), the
/// enrichment layer simply no-ops.
func claudeTranscriptPath(projectsDir: String, cwd: String?, sessionId: String) -> String? {
    guard let cwd, !cwd.isEmpty else { return nil }
    let slug = cwd.replacingOccurrences(of: "/", with: "-")
    return projectsDir + "/" + slug + "/" + sessionId + ".jsonl"
}

/// Observable owner of live session state. Main-thread confined: every method here
/// runs on the main thread, matching the SocketServer handler queue (.main) and the
/// aging Timer's run loop. Do not touch from other threads.
public final class SessionViewModel: ObservableObject {
    @Published public private(set) var sessions: [Session] = []
    @Published public private(set) var badge: BadgeState = BadgeState(needsYouCount: 0)

    struct EnrichmentResult {
        let id: String
        let mtime: Date?
        let summary: TranscriptSummary?
    }

    private let store = SessionStore()
    private let socketPath: String
    private let projectsDir: String
    private let idleAfter: TimeInterval
    private let dropAfter: TimeInterval
    private let enricher: TranscriptEnriching
    private let fileMtime: (String) -> Date?
    private var lastEnriched: [String: Date] = [:]
    private let enrichQueue = DispatchQueue(label: "com.jlk.muster.enrich", qos: .utility)
    private let pidReader: PidSessionReading
    private let liveness: ProcessLiveness

    /// Test seam: lets a test drain the same queue `pollPidSessions` uses before draining main.
    var enrichQueueForTests: DispatchQueue { enrichQueue }

    private var server: SocketServer?
    private var timer: Timer?

    public init(socketPath: String, projectsDir: String, sessionsDir: String = "",
                idleAfter: TimeInterval = 300, dropAfter: TimeInterval = 1800,
                enricher: TranscriptEnriching = TranscriptEnricher(),
                fileMtime: @escaping (String) -> Date? = SessionViewModel.defaultMtime,
                pidReader: PidSessionReading? = nil,
                liveness: ProcessLiveness = DefaultProcessLiveness()) {
        self.socketPath = socketPath
        self.projectsDir = projectsDir
        self.idleAfter = idleAfter
        self.dropAfter = dropAfter
        self.enricher = enricher
        self.fileMtime = fileMtime
        self.pidReader = pidReader ?? PidSessionReader(sessionsDir: sessionsDir)
        self.liveness = liveness
    }

    public static func defaultMtime(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    // MARK: - Pure state transitions (unit-tested)

    public func seed(_ scanned: [ScannedSession], now: Date) {
        for sc in scanned {
            store.seed(Session(
                id: sc.id,
                projectName: projectName(fromCwd: sc.cwd),
                cwd: sc.cwd,
                transcriptPath: sc.path,
                title: sc.title,
                status: .idle,
                lastEventAt: sc.modifiedAt,
                gitBranch: sc.gitBranch,
                model: shortModelName(sc.model),
                lastPrompt: sc.lastPrompt
            ))
            lastEnriched[sc.id] = sc.modifiedAt
        }
        refresh()
    }

    public func ingest(_ event: HookEvent) {
        _ = store.apply(event)
        refresh()
    }

    public func ageNow(_ now: Date) {
        _ = store.age(now: now, idleAfter: idleAfter, dropAfter: dropAfter)
        refresh()
    }

    // MARK: - Enrichment (transcript-derived fields)

    /// Sessions whose transcript file changed since we last enriched them (or never have).
    func sessionsNeedingEnrichment() -> [(id: String, path: String)] {
        store.sessions.values.compactMap { s in
            guard let path = s.transcriptPath else { return nil }
            return lastEnriched[s.id] == fileMtime(path) ? nil : (id: s.id, path: path)
        }
    }

    /// Merge tail-read summaries into the store on the main thread.
    func applyEnrichmentResults(_ results: [EnrichmentResult]) {
        for r in results {
            if let summary = r.summary {
                store.enrich(r.id, gitBranch: summary.gitBranch,
                             model: shortModelName(summary.model),
                             lastPrompt: summary.lastPrompt, title: summary.title)
            }
            lastEnriched[r.id] = r.mtime
        }
        refresh()
    }

    /// Main-thread entry: find changed sessions, read their tails off-main, apply on main.
    func enrichChangedSessions() {
        let work = sessionsNeedingEnrichment()
        guard !work.isEmpty else { return }
        enrichQueue.async { [weak self] in
            guard let self else { return }
            let results = work.map { item in
                EnrichmentResult(id: item.id,
                                 mtime: self.fileMtime(item.path),
                                 summary: self.enricher.enrich(path: item.path))
            }
            DispatchQueue.main.async { self.applyEnrichmentResults(results) }
        }
    }

    private func refresh() {
        sessions = sortedForDisplay(Array(store.sessions.values))
        badge = badgeState(for: sessions)
    }

    // MARK: - Pid-file reconciliation (authoritative liveness + name)

    /// Apply an already-liveness-filtered set of pid-files on the main thread.
    func applyAlivePidSessions(_ alive: [PidSession], now: Date) {
        _ = store.applyPidSessions(alive, now: now) { [projectsDir] p in
            claudeTranscriptPath(projectsDir: projectsDir, cwd: p.cwd, sessionId: p.sessionId)
        }
        refresh()
    }

    /// Main-thread entry: read pid-files + probe liveness off-main, apply on main.
    func pollPidSessions(now: Date) {
        enrichQueue.async { [weak self] in
            guard let self else { return }
            let alive = self.pidReader.read().filter { self.liveness.isAlive($0.pid) }
            DispatchQueue.main.async { self.applyAlivePidSessions(alive, now: now) }
        }
    }

    // MARK: - Live wiring (exercised in Task 13/15, not in unit tests)

    /// Scan disk, start the socket listener, and schedule the aging timer. Main-thread only.
    public func start(now: Date) {
        let scanned = SessionScanner(projectsDir: projectsDir)
            .scan(now: now, within: idleAfter + dropAfter)
        seed(scanned, now: now)
        pollPidSessions(now: now)
        enrichChangedSessions()

        let server = SocketServer(path: socketPath, queue: .main) { [weak self] event in
            self?.ingest(event)
        }
        try? server.start()
        self.server = server

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            let now = Date()
            self?.ageNow(now)
            self?.pollPidSessions(now: now)
            self?.enrichChangedSessions()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        server?.stop()
        server = nil
        timer?.invalidate()
        timer = nil
    }
}
