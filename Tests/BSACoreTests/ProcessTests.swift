import XCTest
@testable import BSACore

final class ProcessTests: XCTestCase {
    func testOutputTruncationFlagAtCaptureLimit() throws {
        let commands = CommandRunner()
        let limit = 1_048_576
        for size in [limit, limit + 1] {
            let result = try commands.run("/bin/sh", ["-c", "head -c \(size) /dev/zero"],
                                          cwd: FileManager.default.temporaryDirectory)

            XCTAssertEqual(result.status, 0)
            XCTAssertFalse(result.timedOut)
            XCTAssertEqual(result.output.utf8.count, limit)
            XCTAssertEqual(result.outputTruncated, size > limit)
            XCTAssertTrue(result.outputIsUTF8)
        }
    }

    func testInvalidUTF8IsFlaggedDespiteReplacementDecoding() throws {
        let result = try CommandRunner().run("/bin/sh", ["-c", "printf 'before\\377after'"],
                                              cwd: FileManager.default.temporaryDirectory)

        XCTAssertEqual(result.status, 0)
        XCTAssertFalse(result.timedOut)
        XCTAssertFalse(result.outputTruncated)
        XCTAssertFalse(result.outputIsUTF8)
        XCTAssertEqual(result.output, "before\u{FFFD}after")
    }
}
