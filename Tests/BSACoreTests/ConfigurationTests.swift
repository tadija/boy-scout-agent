import XCTest
@testable import BSACore

final class ConfigurationTests: XCTestCase {
    func testDefaultEncodingIncludesAutomaticSettingsAsNull() throws {
        let data = try JSONEncoder().encode(Configuration())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object.count, 15)
        for key in ["harness", "customCommand", "branch", "base", "baseline", "verification"] {
            XCTAssertTrue(object[key] is NSNull, "Expected null default for \(key)")
        }
        let decoded = try JSONDecoder().decode(Configuration.self, from: data)
        try decoded.validate()
        XCTAssertEqual(decoded.maxIterations, 1)
        XCTAssertEqual(decoded.commitIdentity, Configuration().commitIdentity)
    }

    func testTimeoutValidationRequiresFinitePositiveValueWithinOneDay() throws {
        var configuration = Configuration()
        for timeout in [Double.nan, .infinity, -.infinity, -1, 0, 86400.0.nextUp] {
            configuration.timeoutSeconds = timeout
            XCTAssertThrowsError(try configuration.validate(), "Accepted timeout: \(timeout)")
        }
        for timeout in [0.001, 1800, 86400] {
            configuration.timeoutSeconds = timeout
            XCTAssertNoThrow(try configuration.validate(), "Rejected timeout: \(timeout)")
        }
    }
}
