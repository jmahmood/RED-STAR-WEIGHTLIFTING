
import XCTest
@testable import WEIGHTLIFTING

final class PlanValidationTests: XCTestCase {
    func testInvalidPlanFailsValidation() throws {
        let invalidJSON = """
        { "name": "Broken Plan", "unit": "lb", "dictionary": {} }
        """
        guard let data = invalidJSON.data(using: .utf8) else {
            XCTFail("Could not build invalid JSON data")
            return
        }

        do {
            _ = try PlanValidator.validate(data: data)
            XCTFail("Expected validation to throw for malformed plan")
        } catch PlanValidationError.decodingFailed, PlanValidationError.missingDays {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
