import Foundation
import Combine
import MusterCore

/// Loads and (optionally) polls a session's transcript for the detail pane. Main-thread only.
public final class TranscriptViewModel: ObservableObject {
    @Published public private(set) var messages: [TranscriptMessage] = []
    @Published public private(set) var title: String?

    public let path: String
    private let reader = TranscriptReader()
    private var timer: Timer?

    public init(path: String) { self.path = path }

    public func load() {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let parsed = reader.parse(contents)
        messages = parsed.messages
        title = parsed.title
    }

    /// Load now and poll once a second for live updates while the detail pane is open.
    public func start() {
        load()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.load() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
