import XCTest
@testable import MusterCore

final class MessageFramerTests: XCTestCase {
    func s(_ d: Data) -> String { String(decoding: d, as: UTF8.self) }

    func testSingleLine() {
        let f = MessageFramer()
        let out = f.push(Data("hello\n".utf8))
        XCTAssertEqual(out.map(s), ["hello"])
    }

    func testMultipleLinesOnePush() {
        let f = MessageFramer()
        let out = f.push(Data("a\nb\nc\n".utf8))
        XCTAssertEqual(out.map(s), ["a", "b", "c"])
    }

    func testPartialLineHeldUntilComplete() {
        let f = MessageFramer()
        XCTAssertEqual(f.push(Data("par".utf8)).map(s), [])
        XCTAssertEqual(f.push(Data("tial\nnext".utf8)).map(s), ["partial"])
        XCTAssertEqual(f.push(Data("\n".utf8)).map(s), ["next"])
    }

    func testEmptyLinesSkipped() {
        let f = MessageFramer()
        XCTAssertEqual(f.push(Data("\n\nx\n".utf8)).map(s), ["x"])
    }
}
