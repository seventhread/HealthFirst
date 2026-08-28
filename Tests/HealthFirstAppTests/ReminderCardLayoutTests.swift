import XCTest
@testable import HealthFirstApp

final class ReminderCardLayoutTests: XCTestCase {
    private let accuracy = 1e-9

    func testFoldedReceiptsLiftTheMascotTowardItsBubble() {
        XCTAssertEqual(
            CompanionReceiptLayout.mascotCenter(for: .endedEarly).y,
            96,
            accuracy: accuracy
        )
        XCTAssertEqual(
            CompanionReceiptLayout.mascotCenter(for: .skipped).y,
            96,
            accuracy: accuracy
        )
        XCTAssertEqual(
            CompanionReceiptLayout.mascotCenter(for: .completed).y,
            150,
            accuracy: accuracy
        )
        XCTAssertEqual(
            CompanionReceiptLayout.foldedEyeMascotCenter.x,
            CompanionReceiptLayout.eyeHeadX,
            accuracy: accuracy
        )
        XCTAssertEqual(
            CompanionReceiptLayout.foldedEyeMascotCenter.y,
            CompanionReceiptLayout.foldedMascotCenter.y,
            accuracy: accuracy
        )
    }

    func testQuietDockSettlesDirectlyAboveMascotWithoutClippingShadow() {
        XCTAssertEqual(
            QuietCompanionLayout.settledDockCenter.x,
            QuietCompanionLayout.settledMascotCenter.x,
            accuracy: accuracy
        )

        let dockLeading = QuietCompanionLayout.settledDockCenter.x
            - QuietCompanionLayout.dockWidth / 2
        XCTAssertGreaterThanOrEqual(
            dockLeading,
            QuietCompanionLayout.dockShadowRadius
        )
    }
}
