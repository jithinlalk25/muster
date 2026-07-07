import XCTest
@testable import MusterCore

final class SessionScannerHardeningTests: XCTestCase {
    var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "muster-scan-hard-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    private func write(project: String, file: String, mtime: Date, contents: String = "{}") throws {
        let dir = root + "/" + project
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/" + file
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: path)
    }

    /// Recent .jsonl files across multiple project dirs are all returned, newest first.
    func testMultiProjectTraversal() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try write(project: "alpha", file: "a.jsonl", mtime: now.addingTimeInterval(-30))
        try write(project: "beta", file: "b.jsonl", mtime: now.addingTimeInterval(-10))
        let scanned = SessionScanner(projectsDir: root).scan(now: now, within: 3600)
        XCTAssertEqual(scanned.map(\.id), ["b", "a"]) // newest first
    }

    /// Non-.jsonl files are ignored even when recent.
    func testNonJsonlExcluded() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try write(project: "alpha", file: "notes.txt", mtime: now)
        try write(project: "alpha", file: "s.jsonl", mtime: now)
        let scanned = SessionScanner(projectsDir: root).scan(now: now, within: 3600)
        XCTAssertEqual(scanned.map(\.id), ["s"])
    }

    /// A file exactly `within` seconds old is included; strictly older is excluded.
    func testWithinBoundaryInclusive() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try write(project: "alpha", file: "edge.jsonl", mtime: now.addingTimeInterval(-3600))
        try write(project: "alpha", file: "past.jsonl", mtime: now.addingTimeInterval(-3601))
        let scanned = SessionScanner(projectsDir: root).scan(now: now, within: 3600)
        XCTAssertEqual(scanned.map(\.id), ["edge"])
    }
}
