import Foundation

/// Produces a TranscriptSummary for a session by reading a bounded tail of its transcript
/// and summarizing it. Injected into the view-model so tests can supply a fake.
public protocol TranscriptEnriching {
    func enrich(path: String) -> TranscriptSummary?
}

public struct TranscriptEnricher: TranscriptEnriching {
    private let reader = TranscriptReader()
    private let maxBytes: Int

    public init(maxBytes: Int = 64 * 1024) { self.maxBytes = maxBytes }

    public func enrich(path: String) -> TranscriptSummary? {
        guard let tail = TranscriptTail.read(path: path, maxBytes: maxBytes) else { return nil }
        return reader.summarize(tail)
    }
}
