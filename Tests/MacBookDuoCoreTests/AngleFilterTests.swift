import XCTest
@testable import MacBookDuoCore

final class AngleFilterTests: XCTestCase {
    func testFirstSampleIsNotDelayed() {
        var filter = AngleFilter(alpha: 0.25)
        XCTAssertEqual(filter.push(100), 100, accuracy: 0.0001)
    }

    func testFilterConvergesWithoutOvershoot() {
        var filter = AngleFilter(alpha: 0.5)
        _ = filter.push(100)
        XCTAssertEqual(filter.push(80), 90, accuracy: 0.0001)
        XCTAssertEqual(filter.push(80), 85, accuracy: 0.0001)
    }

    func testInvalidSampleKeepsLastValue() {
        var filter = AngleFilter(alpha: 0.5)
        _ = filter.push(100)
        XCTAssertEqual(filter.push(.nan), 100, accuracy: 0.0001)
    }
}
