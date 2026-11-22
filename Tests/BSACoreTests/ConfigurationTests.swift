import XCTest
@testable import BSACore

final class ConfigurationTests: XCTestCase {
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
