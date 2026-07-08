import XCTest
@testable import MusterCore

final class PidSessionTests: XCTestCase {
    func decode(_ json: String) throws -> PidSession {
        try JSONDecoder().decode(PidSession.self, from: Data(json.utf8))
    }

    func testDecodesRealSampleAndConvertsEpochMs() throws {
        let json = #"""
        {"pid":63657,"sessionId":"d3eb55e7","cwd":"/Users/jlk/Projects/muster",
         "startedAt":1783498130466,"version":"2.1.204","kind":"interactive",
         "name":"muster-56","nameSource":"derived","status":"busy",
         "updatedAt":1783498215263,"statusUpdatedAt":1783498215263}
        """#
        let p = try decode(json)
        XCTAssertEqual(p.pid, 63657)
        XCTAssertEqual(p.sessionId, "d3eb55e7")
        XCTAssertEqual(p.cwd, "/Users/jlk/Projects/muster")
        XCTAssertEqual(p.name, "muster-56")
        XCTAssertEqual(p.status, .busy)
        XCTAssertEqual(p.statusUpdatedAt, Date(timeIntervalSince1970: 1783498215.263))
    }

    func testMissingNameAndUnknownStatusFallBack() throws {
        let p = try decode(#"{"pid":1,"sessionId":"s","status":"weird","statusUpdatedAt":0}"#)
        XCTAssertNil(p.name)
        XCTAssertEqual(p.status, .idle)   // unknown status → idle
    }

    func testMissingStatusIsIdle() throws {
        let p = try decode(#"{"pid":1,"sessionId":"s","statusUpdatedAt":0}"#)
        XCTAssertEqual(p.status, .idle)
    }

    func testMalformedThrows() {
        XCTAssertThrowsError(try decode(#"{"sessionId":"s"}"#))   // missing pid
        XCTAssertThrowsError(try decode("not json"))
    }

    func testPidOutOfInt32RangeThrows() {
        XCTAssertThrowsError(try decode(#"{"pid":9999999999,"sessionId":"s","status":"idle","statusUpdatedAt":0}"#))
    }

    func testMissingStatusUpdatedAtDefaultsToEpochZero() throws {
        let p = try decode(#"{"pid":1,"sessionId":"s","status":"idle"}"#)
        XCTAssertEqual(p.statusUpdatedAt, Date(timeIntervalSince1970: 0))
    }
}
