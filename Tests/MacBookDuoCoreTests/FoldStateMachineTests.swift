import XCTest
@testable import MacBookDuoCore

final class FoldStateMachineTests: XCTestCase {
    func testFoldEffectKeepsDesktopGeometryFixed() {
        XCTAssertEqual(FoldParameters.make(angle: 50).contentScale, 1)
    }

    func testCrossingTriggerRequestsOneCaptureUntilReset() {
        var model = FoldStateMachine()
        XCTAssertEqual(model.update(angle: 100), .none)
        XCTAssertEqual(model.update(angle: 84), .capture(progress: 1.0 / 70.0))
        XCTAssertEqual(model.update(angle: 70), .render(progress: 15.0 / 70.0))
        XCTAssertEqual(model.update(angle: 84), .render(progress: 1.0 / 70.0))
    }

    func testResetRequiresAngleAboveHysteresisThreshold() {
        var model = FoldStateMachine()
        _ = model.update(angle: 80)
        XCTAssertEqual(model.update(angle: 90), .render(progress: 0))
        XCTAssertEqual(model.update(angle: 93), .hide)
        XCTAssertEqual(model.update(angle: 84), .capture(progress: 1.0 / 70.0))
    }

    func testBlackoutAtAndBelowFifteenDegrees() {
        var model = FoldStateMachine()
        _ = model.update(angle: 80)
        XCTAssertEqual(model.update(angle: 15), .blackout)
        XCTAssertEqual(model.update(angle: 4), .blackout)
    }

    func testInvalidAnglesAreIgnored() {
        var model = FoldStateMachine()
        XCTAssertEqual(model.update(angle: -.infinity), .none)
        XCTAssertEqual(model.update(angle: 181), .none)
        XCTAssertEqual(model.update(angle: .nan), .none)
    }
}
