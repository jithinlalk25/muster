import XCTest
@testable import MusterCore

final class SessionScannerTests: XCTestCase {
    var root: String!

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "muster-scan-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
    }

    func writeSession(project: String, id: String, mtime: Date, title: String) throws {
        let dir = root + "/" + project
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/" + id + ".jsonl"
        let line = #"{"type":"ai-title","aiTitle":"\#(title)","sessionId":"\#(id)"}"# + "\n" +
                   #"{"type":"user","cwd":"/Users/jlk/Projects/\#(project)","message":{"role":"user","content":"hi"}}"#
        try line.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: path)
    }

    func testScanReturnsRecentNewestFirst() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try writeSession(project: "muster", id: "new", mtime: now.addingTimeInterval(-60), title: "New")
        try writeSession(project: "muster", id: "old", mtime: now.addingTimeInterval(-99_999), title: "Old")

        let scanned = SessionScanner(projectsDir: root).scan(now: now, within: 3600)
        XCTAssertEqual(scanned.map(\.id), ["new"])
        XCTAssertEqual(scanned.first?.title, "New")
        XCTAssertEqual(scanned.first?.cwd, "/Users/jlk/Projects/muster")
    }

    func testMissingDirReturnsEmpty() {
        let scanned = SessionScanner(projectsDir: root + "/nope").scan(now: Date(), within: 3600)
        XCTAssertTrue(scanned.isEmpty)
    }
}
