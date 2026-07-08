import XCTest
@testable import MusterCore

final class TranscriptEnricherTests: XCTestCase {
    func testEnrichReadsAndSummarizes() throws {
        let path = NSTemporaryDirectory() + "enrich-\(UUID().uuidString).jsonl"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let jsonl = #"{"type":"assistant","gitBranch":"feat/x","message":{"role":"assistant","model":"claude-sonnet-5","content":[]}}"#
        try jsonl.write(toFile: path, atomically: true, encoding: .utf8)

        let summary = TranscriptEnricher().enrich(path: path)
        XCTAssertEqual(summary?.gitBranch, "feat/x")
        XCTAssertEqual(summary?.model, "claude-sonnet-5")
    }

    func testEnrichMissingFileReturnsNil() {
        XCTAssertNil(TranscriptEnricher().enrich(path: "/no/such/file.jsonl"))
    }
}
