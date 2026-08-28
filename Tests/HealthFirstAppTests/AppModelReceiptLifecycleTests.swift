import AppKit
import XCTest
@testable import HealthFirstApp

@MainActor
final class AppModelReceiptLifecycleTests: XCTestCase {
    func testReceiptExpiresOnScheduleEvenWhilePointerIsOverPanel() throws {
        if NSWorkspace.shared.isVoiceOverEnabled {
            throw XCTSkip("VoiceOver receipts intentionally wait for an explicit close action")
        }

        let model = AppModel()
        model.triggerPreview(.eye)
        model.skipActiveReminder()

        let startedAt = try XCTUnwrap(model.receiptStartedAt)
        XCTAssertEqual(model.receipt, .skipped)

        model.setPanelHovering(true)

        XCTAssertFalse(
            model.finishExpiredReceiptIfNeeded(
                at: startedAt.addingTimeInterval(
                    PanelReceiptPresentationPolicy.bubbleDisplayDuration - 0.001
                )
            )
        )
        XCTAssertEqual(model.receipt, .skipped)

        XCTAssertTrue(
            model.finishExpiredReceiptIfNeeded(
                at: startedAt.addingTimeInterval(
                    PanelReceiptPresentationPolicy.bubbleDisplayDuration
                )
            )
        )
        XCTAssertNil(model.receipt)
        XCTAssertNil(model.receiptStartedAt)
    }
}
