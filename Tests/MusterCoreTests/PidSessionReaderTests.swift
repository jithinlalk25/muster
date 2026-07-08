import XCTest
@testable import MusterCore

final class PidSessionReaderTests: XCTestCase {
    var dir: String!

    override func setUpWithError() throws {
        dir = NSTemporaryDirectory() + "pidread-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: dir)
    }
    func write(_ name: String, _ contents: String) throws {
        try contents.write(toFile: dir + "/" + name, atomically: true, encoding: .utf8)
    }

    func testReadsValidSkipsInvalidAndNonJson() throws {
        try write("1.json", #"{"pid":1,"sessionId":"a","status":"busy","statusUpdatedAt":0}"#)
        try write("2.json", #"{"pid":2,"sessionId":"b","status":"idle","statusUpdatedAt":0}"#)
        try write("bad.json", "not json")                 // skipped
        try write("empty.json", #"{"pid":3,"sessionId":"","statusUpdatedAt":0}"#) // empty id skipped
        try write("notes.txt", "ignored")                 // non-json skipped

        let ids = Set(PidSessionReader(sessionsDir: dir).read().map(\.sessionId))
        XCTAssertEqual(ids, ["a", "b"])
    }

    func testMissingDirReturnsEmpty() {
        let ids = PidSessionReader(sessionsDir: dir + "/nope").read()
        XCTAssertTrue(ids.isEmpty)
    }
}
