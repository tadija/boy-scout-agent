import XCTest
@testable import BSACore

final class OperationsTests: XCTestCase {
    func testDurationValidation() throws {
        XCTAssertEqual(try ExecutionWindow.duration("4h"), 14400)
        for value in ["0h", "-1s", "nanm", "8d", "200h", "4"] {
            XCTAssertThrowsError(try ExecutionWindow.duration(value))
        }
    }
    func testNextLocalOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 5))!
        let deadline = try ExecutionWindow.until("04:00", now: now, calendar: calendar)
        XCTAssertEqual(deadline.timeIntervalSince(now), 23 * 3600)
        XCTAssertThrowsError(try ExecutionWindow.until("24:00"))
        XCTAssertThrowsError(try ExecutionWindow.until("4:00"))
    }
}
