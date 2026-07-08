import Foundation
import Combine
import MusterCore

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

    private var server: SocketServer?
    private var timer: Timer?

    public init(socketPath: String, projectsDir: String,
                idleAfter: TimeInterval = 300, dropAfter: TimeInterval = 1800,
                enricher: TranscriptEnriching = TranscriptEnricher(),
                fileMtime: @escaping (String) -> Date? = SessionViewModel.defaultMtime) {
        self.socketPath = socketPath
        self.projectsDir = projectsDir
        self.idleAfter = idleAfter
        self.dropAfter = dropAfter
        self.enricher = enricher
        self.fileMtime = fileMtime
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

    private func refresh() {
        sessions = sortedForDisplay(Array(store.sessions.values))
        badge = badgeState(for: sessions)
    }

    // MARK: - Live wiring (exercised in Task 13/15, not in unit tests)

    /// Scan disk, start the socket listener, and schedule the aging timer. Main-thread only.
    public func start(now: Date) {
        let scanned = SessionScanner(projectsDir: projectsDir)
            .scan(now: now, within: idleAfter + dropAfter)
        seed(scanned, now: now)

        let server = SocketServer(path: socketPath, queue: .main) { [weak self] event in
            self?.ingest(event)
        }
        try? server.start()
        self.server = server

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.ageNow(Date())
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
