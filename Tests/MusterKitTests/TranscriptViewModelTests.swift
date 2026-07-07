import XCTest
import MusterCore
@testable import MusterKit

final class TranscriptViewModelTests: XCTestCase {
    var path: String!

    override func setUpWithError() throws {
        path = NSTemporaryDirectory() + "transcript-\(UUID().uuidString).jsonl"
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: path)
    }

    func testLoadParsesMessagesAndTitle() throws {
        let lines = [
            #"{"type":"ai-title","aiTitle":"My session","sessionId":"s1"}"#,
            #"{"type":"user","cwd":"/p/muster","message":{"role":"user","content":"hello"}}"#,
        ].joined(separator: "\n")
        try lines.write(toFile: path, atomically: true, encoding: .utf8)

        let vm = TranscriptViewModel(path: path)
        vm.load()
        XCTAssertEqual(vm.title, "My session")
        XCTAssertEqual(vm.messages, [TranscriptMessage(role: .user, text: "hello")])
    }

    func testLoadReflectsAppendedLines() throws {
        try #"{"type":"user","message":{"role":"user","content":"one"}}"#
            .write(toFile: path, atomically: true, encoding: .utf8)
        let vm = TranscriptViewModel(path: path)
        vm.load()
        XCTAssertEqual(vm.messages.count, 1)

        let two = [
            #"{"type":"user","message":{"role":"user","content":"one"}}"#,
            #"{"type":"assistant","message":{"role":"assistant","content":"two"}}"#,
        ].joined(separator: "\n")
        try two.write(toFile: path, atomically: true, encoding: .utf8)
        vm.load()
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages.last?.text, "two")
    }

    func testMissingFileLeavesEmpty() {
        let vm = TranscriptViewModel(path: path + "-nope")
        vm.load()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertNil(vm.title)
    }
}
