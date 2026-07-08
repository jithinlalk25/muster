import XCTest
@testable import MusterCore

final class TranscriptTailTests: XCTestCase {
    var path: String!

    override func setUpWithError() throws {
        path = NSTemporaryDirectory() + "tail-\(UUID().uuidString).txt"
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: path)
    }

    func write(_ s: String) throws { try s.write(toFile: path, atomically: true, encoding: .utf8) }

    func testSmallFileReturnsWholeContents() throws {
        try write("line1\nline2")
        XCTAssertEqual(TranscriptTail.read(path: path, maxBytes: 64 * 1024), "line1\nline2")
    }

    func testTailDropsPartialLeadingLine() throws {
        // "café\n" is 6 bytes (é = 2), "hello" is 5. maxBytes 7 → start lands inside "é".
        try write("café\nhello")
        XCTAssertEqual(TranscriptTail.read(path: path, maxBytes: 7), "hello")
    }

    func testMissingFileReturnsNil() {
        XCTAssertNil(TranscriptTail.read(path: path + "-nope", maxBytes: 1024))
    }
}
